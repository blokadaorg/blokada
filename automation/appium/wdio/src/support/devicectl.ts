import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// Host-side helpers for the physical iOS device, for when WDA's app commands
// are not enough. On the CI iPhone `mobile: terminateApp` sometimes reports
// success while the app keeps running; that stale process can also stop
// exposing Flutter's accessibility tree, so every automation id disappears.

function udid(): string | undefined {
  return process.env.IOS_UDID;
}

function devicectlJson(args: string[]): unknown {
  const dir = mkdtempSync(join(tmpdir(), "devicectl-"));
  const out = join(dir, "out.json");
  try {
    execFileSync("xcrun", ["devicectl", ...args, "--json-output", out], { stdio: "ignore" });
    return JSON.parse(readFileSync(out, "utf8"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function appPids(bundleId: string, device: string): number[] {
  const apps = devicectlJson(["device", "info", "apps", "--device", device, "--bundle-id", bundleId]) as {
    result?: { apps?: Array<{ url?: string }> };
  };
  const appUrl = apps.result?.apps?.[0]?.url;
  if (!appUrl) return [];
  const procs = devicectlJson(["device", "info", "processes", "--device", device]) as {
    result?: { runningProcesses?: Array<{ executable?: string; processIdentifier?: number }> };
  };
  return (procs.result?.runningProcesses ?? [])
    .filter((p) => p.executable?.startsWith(appUrl) && typeof p.processIdentifier === "number")
    .map((p) => p.processIdentifier as number);
}

/** SIGKILL every running process of the app. Returns false when not possible here. */
export function forceKillIosApp(bundleId: string): boolean {
  const device = udid();
  if (!device) return false;
  try {
    const pids = appPids(bundleId, device);
    for (const pid of pids) {
      execFileSync(
        "xcrun",
        ["devicectl", "device", "process", "terminate", "--device", device, "--pid", String(pid), "--kill"],
        { stdio: "ignore" }
      );
    }
    console.warn(`devicectl: killed ${pids.length} process(es) of ${bundleId}`);
    return true;
  } catch (error) {
    console.warn(`devicectl: force kill of ${bundleId} failed: ${String(error)}`);
    return false;
  }
}
