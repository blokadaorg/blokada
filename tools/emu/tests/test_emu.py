#!/usr/bin/env python3
"""Local tests for pod/server.py and the emu log client, with fake adb and forwarder."""
import http.client
import os
import socket
import stat
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
EMU = os.path.join(HERE, "..", "emu")
SERVER = os.path.join(HERE, "..", "pod", "server.py")

FAKE_ADB = """#!/bin/bash
[ "$1" = "-s" ] && shift 2
[ "$1" = get-state ] && { echo device; exit 0; }
echo "adb $*"
"""
FAKE_FORWARDER = """import time
print("I0000 ADB forwarding listening on localhost:5555", flush=True)
time.sleep(600)
"""
# Drops its stream once, like a reset gRPC stream, then stays up.
FLAKY_FORWARDER = """import os, sys, time
marker = os.path.join(os.path.dirname(sys.argv[0]), "dropped")
print("I0000 ADB forwarding listening on localhost:5555", flush=True)
if not os.path.exists(marker):
    open(marker, "w").close()
    time.sleep(1)
    sys.exit(1)
time.sleep(600)
"""
FAKE_GCLOUD = "#!/bin/bash\necho tok\n"


def write(path, body, mode=0o755):
    with open(path, "w") as f:
        f.write(body)
    os.chmod(path, mode)


class ServerCase(unittest.TestCase):
    max_age = "2"
    forwarder = FAKE_FORWARDER

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        bindir = os.path.join(cls.tmp, "bin")
        os.mkdir(bindir)
        write(os.path.join(bindir, "adb"), FAKE_ADB)
        write(os.path.join(bindir, "gcloud"), FAKE_GCLOUD)
        write(os.path.join(cls.tmp, "fwd.py"), cls.forwarder, stat.S_IRUSR | stat.S_IWUSR)
        with socket.socket() as s:
            s.bind(("127.0.0.1", 0))
            cls.port = s.getsockname()[1]
        cls.env = dict(
            os.environ,
            PATH=bindir + os.pathsep + os.environ["PATH"],
            PORT=str(cls.port),
            JOBS_DIR=os.path.join(cls.tmp, "jobs"),
            WORKDIR=os.path.join(cls.tmp, "work"),
            LOG_MAX_AGE=cls.max_age,
            FORWARDER_CMD=f"{sys.executable} {cls.tmp}/fwd.py",
        )
        cls.proc = subprocess.Popen([sys.executable, SERVER], env=cls.env)
        deadline = time.time() + 15
        while time.time() < deadline:
            try:
                if "adb=device" in cls.get("/healthz")[1]:
                    return
            except OSError:
                pass
            time.sleep(0.2)
        raise RuntimeError("server did not become healthy")

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        cls.proc.wait()

    @classmethod
    def get(cls, path):
        c = http.client.HTTPConnection("127.0.0.1", cls.port, timeout=30)
        c.request("GET", path)
        r = c.getresponse()
        out = r.status, r.read().decode()
        c.close()
        return out

    @classmethod
    def run_cmd(cls, cmd, chunked=False):
        c = http.client.HTTPConnection("127.0.0.1", cls.port, timeout=30)
        c.request("POST", "/run", body=cmd.encode(), encode_chunked=chunked,
                  headers={"Transfer-Encoding": "chunked"} if chunked else {})
        r = c.getresponse()
        out = r.status, r.read().decode().strip()
        c.close()
        return out


class TestServer(ServerCase):
    def test_healthz(self):
        status, body = self.get("/healthz")
        self.assertEqual(status, 200)
        self.assertIn("forwarder=ready", body)
        self.assertIn("adb=device", body)

    def test_run_content_length_and_serial(self):
        status, job = self.run_cmd('echo "serial=$ANDROID_SERIAL"; adb shell id; exit 3')
        self.assertEqual(status, 200)
        _, out = self.get(f"/log?id={job}&offset=0")
        self.assertEqual(out, f"serial=localhost:5555\nadb shell id\n\nEXIT {job} 3\n")

    def test_run_chunked_body(self):
        _, job = self.run_cmd("echo chunked-ok", chunked=True)
        _, out = self.get(f"/log?id={job}&offset=0")
        self.assertEqual(out, f"chunked-ok\n\nEXIT {job} 0\n")

    def test_offset(self):
        _, job = self.run_cmd("echo abcdef")
        _, out = self.get(f"/log?id={job}&offset=3")
        self.assertEqual(out, f"def\n\nEXIT {job} 0\n")
        _, out = self.get(f"/log?id={job}&offset=7")
        self.assertEqual(out, f"\nEXIT {job} 0\n")

    def test_stream_cut_has_no_exit_then_reconnect(self):
        _, job = self.run_cmd("echo a; sleep 4; echo b")
        _, first = self.get(f"/log?id={job}&offset=0")
        self.assertEqual(first, "a\n")  # cut at max age, no EXIT
        rest = ""
        while not rest.endswith(f"\nEXIT {job} 0\n"):  # reconnect like the client
            rest += self.get(f"/log?id={job}&offset={len(first) + len(rest)}")[1]
        self.assertEqual(rest, f"b\n\nEXIT {job} 0\n")

    def test_unknown_job(self):
        self.assertEqual(self.get("/log?id=000000000000&offset=0")[0], 404)
        self.assertEqual(self.get("/log?id=../x&offset=0")[0], 404)


class TestRestart(ServerCase):
    forwarder = FLAKY_FORWARDER

    def test_forwarder_restarts_after_drop(self):
        deadline = time.time() + 20
        while time.time() < deadline:
            body = self.get("/healthz")[1]
            if "restarts=1" in body and "forwarder=ready" in body:
                return
            time.sleep(0.5)
        self.fail(f"forwarder did not come back: {body}")


class TestClient(ServerCase):
    def drive(self, script):
        env = dict(self.env, EMU_POD_BASE=f"http://127.0.0.1:{self.port}",
                   EMU_STATE_DIR=self.tmp)
        r = subprocess.run(
            ["bash", "-c", f'source "{EMU}"; set +e; {script}; echo "rc=$?"'],
            env=env, capture_output=True, text=True, timeout=60,
        )
        return r.stdout

    def test_pod_run_follows_cut_and_returns_exit_code(self):
        out = self.drive("pod_run 'echo one; sleep 4; echo two; exit 4'")
        self.assertEqual(out, "one\ntwo\nrc=4\n")

    def test_pod_run_no_trailing_newline(self):
        out = self.drive("pod_run 'printf abc'")
        self.assertEqual(out, "abcrc=0\n")


if __name__ == "__main__":
    unittest.main()
