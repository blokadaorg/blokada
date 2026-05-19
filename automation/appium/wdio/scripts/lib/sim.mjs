import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const IOS_DIR = resolve(HERE, "..", "..", "..", "..", "..", "ios");

/**
 * Reads the per-worktree iOS Simulator name + UDID from `make -C ios sim-status`.
 *
 * The sim itself is provisioned (auto-cloned) by `make run-{six,family}-mocked`
 * in ios/make/sim-helpers.mk; once it exists, `sim-status` prints `SIM_NAME:`
 * and `SIM_UDID:` lines we can parse.
 *
 * Throws if the sim has not been provisioned yet — the harness has no business
 * guessing which sim to target.
 */
export function resolveSimulatorDevice() {
  const stdout = execFileSync("make", ["-C", IOS_DIR, "sim-status"], {
    encoding: "utf8"
  });

  const udidMatch = stdout.match(/^SIM_UDID:\s*([0-9A-Fa-f-]+)\s*$/m);
  const nameMatch = stdout.match(/^SIM_NAME:\s*(.+?)\s*$/m);

  if (!udidMatch) {
    throw new Error(
      "Simulator UDID not found in `make -C ios sim-status` output. " +
        "The worktree's simulator has not been provisioned yet — run " +
        "`make -C ios run-six-mocked` (or run-family-mocked) once to create it.\n\n" +
        `sim-status output:\n${stdout}`
    );
  }

  return {
    udid: udidMatch[1].trim(),
    name: (nameMatch?.[1] ?? `iPhone Simulator (${udidMatch[1]})`).trim()
  };
}
