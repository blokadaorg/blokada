#!/usr/bin/env node

// Discovers the dependency-update validation queue and prints it as JSON.
// Two sources:
//   1. Open Dependabot PRs the auto-merge workflow hands to a human (major
//      bumps, non-allowlist files, github-actions), plus high-risk packages
//      (Adapty, Firebase, WireGuard, pigeon, gradle/AGP) at any bump level.
//   2. Advisory entries for ecosystems Dependabot does not scan: iOS Swift
//      Package Manager and the wireguard-apple / translate submodules. These
//      are version-drift notes only — there is no PR to validate.
//
// See .agents/skills/dep-validate/SKILL.md for the loop that consumes this.

import process from "node:process";

import {
  discoverAdvisories,
  discoverDependabotQueue
} from "./lib/queue.mjs";

async function main() {
  const queue = discoverDependabotQueue();
  const advisories =
    process.env.SKIP_ADVISORIES === "1" ? [] : discoverAdvisories();

  process.stdout.write(
    JSON.stringify({ queue, advisories }, null, 2) + "\n"
  );

  process.stderr.write(
    `dep-validate queue: ${queue.length} PR(s) need validation, ` +
      `${advisories.length} advisory item(s)\n`
  );
}

await main();
