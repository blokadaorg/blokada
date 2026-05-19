import { spawn } from "node:child_process";
import { createInterface } from "node:readline";

export class JsonlExplorerClient {
  constructor({
    cwd,
    env = process.env,
    log = console.error,
    nodePath = process.execPath,
    scriptPath = "scripts/explore.mjs"
  } = {}) {
    this.cwd = cwd;
    this.env = env;
    this.log = log;
    this.nodePath = nodePath;
    this.pending = new Map();
    this.nextId = 1;
    this.process = undefined;
    this.scriptPath = scriptPath;
  }

  start() {
    if (this.process) {
      return;
    }

    this.process = spawn(this.nodePath, [this.scriptPath, "--jsonl"], {
      cwd: this.cwd,
      env: this.env,
      stdio: ["pipe", "pipe", "pipe"]
    });

    const rl = createInterface({
      input: this.process.stdout,
      crlfDelay: Infinity,
      terminal: false
    });

    rl.on("line", (line) => this.handleLine(line));
    this.process.stderr.on("data", (data) => {
      this.log(String(data));
    });
    this.process.once("exit", (code, signal) => {
      const message = `Appium explorer process exited with code ${code ?? "null"} signal ${signal ?? "null"}.`;
      for (const [, pending] of this.pending) {
        pending.reject(new Error(message));
      }
      this.pending.clear();
    });
  }

  handleLine(line) {
    let event;
    try {
      event = JSON.parse(line);
    } catch (_) {
      this.log(line);
      return;
    }

    const pending = this.pending.get(event.id);
    if (!pending) {
      return;
    }

    if (event.type === "result") {
      pending.result = event;
      return;
    }

    if (event.type === "error") {
      this.pending.delete(event.id);
      pending.reject(new Error(event.error ?? "Explorer command failed."));
      return;
    }

    if (event.type === "done") {
      this.pending.delete(event.id);
      pending.resolve(pending.result ?? event);
    }
  }

  command(command, args = {}) {
    if (!this.process?.stdin?.writable) {
      return Promise.reject(new Error("Explorer process is not running."));
    }

    const id = String(this.nextId);
    this.nextId += 1;

    const payload = {
      id,
      command,
      args
    };

    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject, result: undefined });
      this.process.stdin.write(`${JSON.stringify(payload)}\n`, (error) => {
        if (error) {
          this.pending.delete(id);
          reject(error);
        }
      });
    });
  }

  async shutdown() {
    if (!this.process) {
      return;
    }

    if (this.process.stdin?.writable) {
      await this.command("session.shutdown", {}).catch((error) => {
        this.log(`Explorer shutdown command failed: ${String(error)}`);
      });
    }

    await new Promise((resolve) => {
      if (!this.process || this.process.exitCode != null) {
        resolve();
        return;
      }

      const timeout = setTimeout(() => {
        this.process?.kill("SIGTERM");
        resolve();
      }, 10000);

      this.process.once("exit", () => {
        clearTimeout(timeout);
        resolve();
      });
    });
  }
}
