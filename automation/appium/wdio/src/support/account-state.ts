import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

import { ensureDirectory } from "./files.js";

// Records which account the device was last restored to DURING THE CURRENT RUN,
// so per-spec ensureAccount{Active,Inactive} can skip the expensive restore (app
// relaunch + support-chat command + network round trip) when the device is
// already in the needed state. Reset once per run by the wdio onPrepare hook (see
// wdio.conf.ts), so a fresh run never trusts a prior run's state — the first spec
// of a run always restores, later same-account specs skip. Lives under output/
// (git-ignored). Shared by the launcher (onPrepare reset) and the workers
// (account.ts read/write), which run with the same cwd (the wdio dir).
//
// Keep this module DRIVER-FREE (no @wdio/globals / driver): onPrepare runs in the
// launcher process where the browser session doesn't exist, so importing driver
// here would break the reset.
const stateFile = resolve(process.cwd(), "..", "output", ".account-state");

/** The account id the device was last restored to this run, or null if unknown. */
export function readCurrentAccount(): string | null {
  try {
    if (!existsSync(stateFile)) return null;
    const value = readFileSync(stateFile, "utf8").trim();
    return value.length > 0 ? value : null;
  } catch {
    return null;
  }
}

/** Record the account id the device was just restored to. */
export function writeCurrentAccount(accountId: string): void {
  try {
    ensureDirectory(stateFile); // output/ may not exist yet on a fresh checkout
    writeFileSync(stateFile, accountId, "utf8");
  } catch (error) {
    console.warn(`Failed to record account state: ${String(error)}`);
  }
}

/** Clear the per-run record so the next spec restores unconditionally. */
export function resetAccountState(): void {
  try {
    rmSync(stateFile, { force: true });
  } catch (error) {
    console.warn(`Failed to reset account state: ${String(error)}`);
  }
}
