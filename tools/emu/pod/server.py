#!/usr/bin/env python3
"""Device pod server: runs the ADB forwarder and exposes shell jobs over HTTP/1.1.

POST /run (body = shell command) -> job id; GET /log?id=&offset= streams the job
output and ends with "\nEXIT <id> <code>\n"; GET /healthz reports forwarder and adb state.
"""
import http.server
import os
import re
import shlex
import socketserver
import subprocess
import sys
import threading
import time
import urllib.parse
import uuid

JOBS = os.environ.get("JOBS_DIR", "/tmp/jobs")
WORKDIR = os.environ.get("WORKDIR", "/work")
MAX_AGE = float(os.environ.get("LOG_MAX_AGE", "480"))
MAX_IDLE = float(os.environ.get("LOG_MAX_IDLE", "240"))
MAX_BODY = 1 << 20
ID_RE = re.compile(r"^[0-9a-f]{12}$")
PORT_RE = re.compile(r"listening on localhost:(\d+)")
MAX_RESTARTS = int(os.environ.get("FORWARDER_MAX_RESTARTS", "5"))


class Forwarder:
    """Owns the forwarder process; state is starting, ready or exited.

    The device stream can drop mid-session, so the forwarder is restarted until
    the session deadline, up to MAX_RESTARTS times.
    """

    def __init__(self):
        self.state = "starting"
        self.serial = None
        self.code = None
        self.restarts = 0

    def start(self, argv_for, deadline):
        threading.Thread(target=self._run, args=(argv_for, deadline), daemon=True).start()

    def _run(self, argv_for, deadline):
        while True:
            proc = subprocess.Popen(
                argv_for(int(deadline - time.time())),
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            )
            self._pump(proc)
            if self.restarts >= MAX_RESTARTS or deadline - time.time() < 60:
                self.state = "exited"
                return
            self.restarts += 1
            self.state = "starting"
            time.sleep(5)

    def _pump(self, proc):
        for line in proc.stdout:
            sys.stdout.write("forwarder: " + line)
            sys.stdout.flush()
            m = PORT_RE.search(line)
            if m and self.state == "starting":
                self.serial = "localhost:" + m.group(1)
                os.environ["ANDROID_SERIAL"] = self.serial
                self.state = "ready"
        self.code = proc.wait()


FWD = Forwarder()


def job_path(job, ext):
    return os.path.join(JOBS, job + ext)


def read_exit(job):
    try:
        with open(job_path(job, ".exit")) as f:
            return int(f.read().strip())
    except (FileNotFoundError, ValueError):
        return None


def start_job(cmd):
    job = uuid.uuid4().hex[:12]
    log = open(job_path(job, ".log"), "wb")
    proc = subprocess.Popen(
        ["bash", "-c", cmd],
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        cwd=WORKDIR,
        start_new_session=True,
    )
    log.close()

    def wait():
        code = proc.wait()
        tmp = job_path(job, ".tmp")
        with open(tmp, "w") as f:
            f.write(str(code))
        os.rename(tmp, job_path(job, ".exit"))

    threading.Thread(target=wait, daemon=True).start()
    return job


def adb_state():
    if FWD.state != "ready":
        return "none"
    try:
        out = subprocess.run(
            ["adb", "-s", FWD.serial, "get-state"],
            capture_output=True, text=True, timeout=5,
        )
    except (subprocess.TimeoutExpired, OSError):
        return "unknown"
    return out.stdout.strip() or "unknown"


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    timeout = 60

    def log_message(self, fmt, *args):
        sys.stdout.write("http: " + fmt % args + "\n")
        sys.stdout.flush()

    def reply(self, status, body):
        data = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def read_body(self):
        if "chunked" in self.headers.get("Transfer-Encoding", "").lower():
            out = b""
            while True:
                size = int(self.rfile.readline().split(b";")[0].strip() or b"0", 16)
                if size == 0:
                    while self.rfile.readline().strip():
                        pass  # trailers
                    return out
                out += self.rfile.read(size)
                self.rfile.readline()
                if len(out) > MAX_BODY:
                    raise ValueError("body too large")
        n = int(self.headers.get("Content-Length") or 0)
        if n > MAX_BODY:
            raise ValueError("body too large")
        return self.rfile.read(n)

    def do_POST(self):
        if urllib.parse.urlsplit(self.path).path != "/run":
            return self.reply(404, "not found\n")
        try:
            cmd = self.read_body().decode()
        except (ValueError, UnicodeDecodeError) as e:
            self.close_connection = True
            return self.reply(400, f"bad request: {e}\n")
        # The forwarder reports its port before adb has connected to it.
        if FWD.state != "ready" or adb_state() != "device":
            return self.reply(503, f"device not ready: forwarder {FWD.state}\n")
        self.reply(200, start_job(cmd) + "\n")

    def do_GET(self):
        url = urllib.parse.urlsplit(self.path)
        if url.path == "/healthz":
            return self.reply(
                200, f"forwarder={FWD.state}\nadb={adb_state()}\nrestarts={FWD.restarts}\n"
            )
        if url.path == "/log":
            return self.stream_log(urllib.parse.parse_qs(url.query))
        self.reply(404, "not found\n")

    def chunk(self, data):
        self.wfile.write(b"%x\r\n" % len(data) + data + b"\r\n")
        self.wfile.flush()

    def stream_log(self, q):
        job = (q.get("id") or [""])[0]
        try:
            pos = int((q.get("offset") or ["0"])[0])
        except ValueError:
            pos = -1
        if not ID_RE.match(job) or pos < 0 or not os.path.exists(job_path(job, ".log")):
            return self.reply(404, "unknown job\n")
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Transfer-Encoding", "chunked")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        start = last = time.time()
        try:
            while True:
                code = read_exit(job)  # read before the data so no tail is lost
                with open(job_path(job, ".log"), "rb") as f:
                    f.seek(pos)
                    data = f.read(65536)
                now = time.time()
                if data:
                    self.chunk(data)
                    pos += len(data)
                    last = now
                elif code is not None:
                    # The job id keeps command output from passing for the marker.
                    self.chunk(b"\nEXIT %s %d\n" % (job.encode(), code))
                    break
                elif now - start > MAX_AGE or now - last > MAX_IDLE:
                    break  # no EXIT: the client reconnects
                else:
                    time.sleep(0.1)
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True


def main():
    os.makedirs(JOBS, exist_ok=True)
    os.makedirs(WORKDIR, exist_ok=True)
    cmd = os.environ.get("FORWARDER_CMD")
    deadline = time.time() + int(os.environ.get("TTL", "900"))
    if cmd:
        argv_for = lambda ttl: shlex.split(cmd)  # noqa: E731
    else:
        argv_for = lambda ttl: [  # noqa: E731
            sys.executable, "/app/adb_forwarder.py",
            "--device_session=" + os.environ["DEVICE_SESSION"],
            "--ttl=" + str(max(ttl, 60)),
        ]
    FWD.start(argv_for, deadline)
    Server(("", int(os.environ.get("PORT", "8080"))), Handler).serve_forever()


if __name__ == "__main__":
    main()
