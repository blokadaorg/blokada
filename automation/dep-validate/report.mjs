#!/usr/bin/env node

// Renders a dep-validate run into a markdown report artifact and, on escalation,
// upserts a structured comment on the Dependabot PR.
//
// Input: a JSON decision payload on stdin (or --input <file>) shaped like:
//   {
//     "pr": 1082,
//     "summary": "flutter-dependencies group (22 updates)",
//     "highlights": ["adapty_flutter 3.11.4→3.17.0", "pigeon 12→26 (major)"],
//     "surfaces": ["payment", "platform-bridge"],
//     "stages": [
//       { "name": "unit+static", "status": "pass", "detail": "make test green; analyze clean" },
//       { "name": "mocked-sim",  "status": "pass", "detail": "app launches, onboarding ok" },
//       { "name": "real-device", "status": "blocked", "detail": "no device reachable" }
//     ],
//     "classification": "escalate",          // "proceed" | "escalate"
//     "question": "Adapty 3.17 changes paywall config API ...",   // escalate only
//     "releaseNoteQuote": "...",                                  // escalate only
//     "recommendation": "hold",               // "proceed-with-merge" | "hold" | "rollback"
//     "artifacts": ["automation/appium/output/paywall.png"]
//   }
//
// Flags:
//   --input <file>   read payload from a file instead of stdin
//   --comment        upsert a PR comment (only fires when classification=escalate)
//
// Status values per stage: pass | fail | skip | blocked.
// "blocked" = the stage could not run (no device, missing account id). It is
// NOT a pass: a blocked revenue/protection stage forces classification=escalate.
//
// See .agents/skills/dep-validate/SKILL.md.

import { execFileSync } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const moduleDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(moduleDir, "..", "..");
const REPO = "blokadaorg/blokada";
const OUTPUT_DIR = resolve(repoRoot, "automation", "dep-validate", "output");

function commentMarker(pr) {
  return `<!-- dep-validate:pr${pr} -->`;
}

const STATUS_ICON = {
  pass: "✅",
  fail: "❌",
  skip: "⏭️",
  blocked: "🚧"
};

function renderStages(stages = []) {
  if (!stages.length) return "_no stages recorded_";
  const rows = stages.map(
    (s) =>
      `| ${STATUS_ICON[s.status] ?? "•"} ${s.status} | ${s.name} | ${
        s.detail ?? ""
      } |`
  );
  return ["| Result | Stage | Detail |", "| --- | --- | --- |", ...rows].join(
    "\n"
  );
}

// Per-surface Stage D checks. Keyed to the business surfaces queue.mjs assigns
// (payment, protection, messaging, platform-bridge, build-system). Phrased as
// neutral descriptions of what the on-device smoke validates — not as steps a
// human runs; the agent runs Stage D itself.
const SURFACE_GATES = {
  payment:
    "paywall product fetch, purchase, and restore (real StoreKit / Adapty)",
  protection:
    "protection start — DNS/VPN tunnel comes up (real NetworkExtension)",
  messaging: "push / notification delivery",
  "platform-bridge":
    "native↔Dart calls on the affected screens (watch for `PlatformException`)",
  "build-system": "clean build, install, and cold-launch"
};

const DEVICE_RE = /device|stage\s*d|real[-\s]?device|on[-\s]?device/i;
const SEAM_RE = /purchase|restore|store\s*kit|sandbox/i;

function deviceStages(p) {
  return (p.stages ?? []).filter((s) => DEVICE_RE.test(s.name ?? ""));
}
function anyDeviceStageRan(p) {
  return deviceStages(p).some((s) => s.status === "pass" || s.status === "fail");
}
function blockedDeviceStages(p) {
  return deviceStages(p).filter(
    (s) => s.status === "blocked" || s.status === "skip"
  );
}

// No device at all: on-device work was attempted-but-blocked and nothing ran.
// This is the "re-run the agent where it has a device" case.
function noDeviceRun(p) {
  return blockedDeviceStages(p).length > 0 && !anyDeviceStageRan(p);
}

// Seam: the agent DID run on a device (some device stage passed/failed) but a
// purchase/restore leg specifically could not be driven — the StoreKit sandbox
// sheet is a system UI needing Apple-ID/Face-ID confirmation. Escalate just
// that leg, not the whole stage.
function purchaseSeamBlocked(p) {
  return (
    anyDeviceStageRan(p) &&
    blockedDeviceStages(p).some(
      (s) => SEAM_RE.test(s.name ?? "") || SEAM_RE.test(s.detail ?? "")
    )
  );
}

// Degraded escalation for when Stage D could not run here. Per issue-tracker
// #320 the loop is NOT handed to a human as steps to run — the agent runs the
// whole loop end to end, including real hardware. So this does not emit a
// human runbook: it says re-run the agent where it has a device, lists the
// surfaces still unvalidated, and names the one step no agent can drive (the
// StoreKit sandbox sheet). `compact` trims the trailing note for the PR comment.
function renderDeviceGap(p, { compact = false } = {}) {
  const lines = [];
  lines.push("## Real-hardware validation pending");
  lines.push("");
  lines.push(
    "Stage D could not run in this environment — no device reachable. It validates what the mocked schemes stub, so it is not optional for these surfaces. **Re-run this agent on a device-connected host** (local, or the self-hosted runner `appium-smoke.yml` uses) so it completes the real-hardware smoke itself. This is not a set of steps for a human to run."
  );
  lines.push("");
  lines.push("Surfaces still needing on-device validation:");
  const surfaces = p.surfaces?.length ? p.surfaces : ["(general)"];
  for (const s of surfaces) {
    lines.push(
      `- **${s}** — ${
        SURFACE_GATES[s] ?? "screens this dependency touches"
      }`
    );
  }
  if (!compact) {
    lines.push("");
    lines.push(
      "The only step no agent can drive is the StoreKit **sandbox purchase sheet** (a system UI); the device-connected host needs a sandbox Apple ID signed in so the agent can reach purchase / restore."
    );
  }
  return lines.join("\n");
}

// Focused seam escalation: the agent ran Stage D on a device and validated what
// it could; only the purchase/restore confirmation (StoreKit sandbox sheet)
// remained. This is the single irreducible human/system-UI touch — not a
// re-run, and not a runbook.
function renderPurchaseSeam(p, { compact = false } = {}) {
  const lines = [];
  lines.push("## Purchase / restore — sandbox-sheet seam");
  lines.push("");
  lines.push(
    "The agent validated the on-device surfaces it can drive; the one leg it cannot complete is the StoreKit **sandbox purchase sheet** (a system UI requiring Apple-ID / Face-ID confirmation). Confirm purchase + restore complete on the device-connected host, or accept that residual risk explicitly."
  );
  if (!compact) {
    lines.push("");
    lines.push(
      "Everything up to the purchase confirmation (SDK init, product fetch, paywall render) was exercised — see the stage table above for what passed."
    );
  }
  return lines.join("\n");
}

function renderReport(p, stampIso) {
  const lines = [];
  lines.push(`# dep-validate report — PR #${p.pr}`);
  lines.push("");
  lines.push(`- run: ${stampIso}`);
  lines.push(`- subject: ${p.summary ?? "(none)"}`);
  if (p.highlights?.length) {
    lines.push(`- highlights: ${p.highlights.join("; ")}`);
  }
  if (p.surfaces?.length) {
    lines.push(`- business surfaces: ${p.surfaces.join(", ")}`);
  }
  lines.push(`- classification: **${p.classification ?? "?"}**`);
  if (p.recommendation) {
    lines.push(`- recommendation: **${p.recommendation}**`);
  }
  lines.push("");
  lines.push("## Validation stages");
  lines.push("");
  lines.push(renderStages(p.stages));
  lines.push("");
  if (p.classification === "escalate") {
    lines.push("## Escalation — human judgement required");
    lines.push("");
    if (p.question) lines.push(`**Question:** ${p.question}`);
    if (p.releaseNoteQuote) {
      lines.push("");
      lines.push("**Release-note evidence:**");
      lines.push("");
      lines.push("> " + p.releaseNoteQuote.split("\n").join("\n> "));
    }
    lines.push("");
  }
  // The device-gap / seam blocks are escalation content, derived from the
  // real-device:* stage names. Gate them on classification so a "proceed" run
  // that happens to name a skipped stage with a device keyword cannot emit a
  // spurious "real-hardware validation pending" section. A genuinely blocked
  // revenue/protection stage forces classification=escalate upstream, so this
  // never hides a real gap.
  if (p.classification === "escalate") {
    if (noDeviceRun(p)) {
      lines.push(renderDeviceGap(p));
      lines.push("");
    } else if (purchaseSeamBlocked(p)) {
      lines.push(renderPurchaseSeam(p));
      lines.push("");
    }
  }
  if (p.artifacts?.length) {
    lines.push("## Artifacts");
    lines.push("");
    for (const a of p.artifacts) lines.push(`- \`${a}\``);
    lines.push("");
  }
  lines.push("---");
  lines.push(
    "_Generated by `automation/dep-validate/report.mjs` for blokadaorg/issue-tracker#320._"
  );
  return lines.join("\n");
}

// PR comment body is a compact version of the report. Keep it free of any
// private issue-tracker detail (public repo) and reference #320 without a
// closing keyword to avoid cross-repo auto-close.
function renderComment(p, artifactPath) {
  const lines = [];
  lines.push(commentMarker(p.pr));
  lines.push(`### dep-validate: **${p.classification}** — human review required`);
  lines.push("");
  lines.push(`**${p.summary ?? `PR #${p.pr}`}**`);
  if (p.highlights?.length) {
    lines.push("");
    lines.push(p.highlights.map((h) => `- ${h}`).join("\n"));
  }
  lines.push("");
  lines.push(renderStages(p.stages));
  lines.push("");
  if (p.question) {
    lines.push(`**Question for you:** ${p.question}`);
    lines.push("");
  }
  if (p.releaseNoteQuote) {
    lines.push("> " + p.releaseNoteQuote.split("\n").join("\n> "));
    lines.push("");
  }
  if (p.recommendation) {
    lines.push(`**Recommendation:** ${p.recommendation}`);
    lines.push("");
  }
  // Escalation-only blocks. renderComment is already called only on escalate
  // (see main()), but gate defensively so the same name-derived blocks cannot
  // leak into a non-escalate comment if this is ever called directly.
  if (p.classification === "escalate") {
    if (noDeviceRun(p)) {
      lines.push(renderDeviceGap(p, { compact: true }));
      lines.push("");
    } else if (purchaseSeamBlocked(p)) {
      lines.push(renderPurchaseSeam(p, { compact: true }));
      lines.push("");
    }
  }
  lines.push(`Full report: \`${artifactPath}\``);
  lines.push("");
  lines.push(
    "_Automated dependency validation (issue-tracker #320). Not a merge gate._"
  );
  return lines.join("\n");
}

function gh(args, opts = {}) {
  return execFileSync("gh", args, {
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
    ...opts
  });
}

// Upsert: edit our existing marked comment if present, else create one. Keeps
// re-runs (including headless) from spamming the PR with duplicate comments.
async function upsertComment(pr, body) {
  const marker = commentMarker(pr);
  let viewer = "";
  try {
    viewer = gh(["api", "user", "--jq", ".login"]).trim();
  } catch {
    viewer = "";
  }

  const existing = JSON.parse(
    gh([
      "api",
      "--paginate",
      `repos/${REPO}/issues/${pr}/comments`,
      "--jq",
      "[.[] | {id, login: .user.login, type: .user.type, body}]"
    ])
  );
  // Match our own marked comment to upsert. When the viewer is known (PAT),
  // require the author to be us. When it is not (App-installation token, where
  // `gh api user` fails), fall back to bot/app authors only — never PATCH a
  // human-authored comment that happens to contain the marker; post a new one
  // instead.
  const isBot = (c) =>
    c.type === "Bot" || /\[bot\]$/i.test(c.login ?? "");
  const mine = existing.find(
    (c) =>
      c.body?.includes(marker) && (viewer ? c.login === viewer : isBot(c))
  );

  const tmp = resolve(OUTPUT_DIR, `.comment-${pr}.md`);
  await writeFile(tmp, body, "utf8");

  if (mine) {
    gh([
      "api",
      "-X",
      "PATCH",
      `repos/${REPO}/issues/comments/${mine.id}`,
      "-F",
      `body=@${tmp}`
    ]);
    return { action: "updated", id: mine.id };
  }
  gh([
    "api",
    "-X",
    "POST",
    `repos/${REPO}/issues/${pr}/comments`,
    "-F",
    `body=@${tmp}`
  ]);
  return { action: "created" };
}

async function readStdin() {
  const chunks = [];
  for await (const c of process.stdin) chunks.push(c);
  return Buffer.concat(chunks).toString("utf8");
}

function parseArgs(argv) {
  const args = { comment: false, input: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--comment") args.comment = true;
    else if (argv[i] === "--input") {
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) {
        throw new Error("--input requires a file path");
      }
      args.input = argv[++i];
    }
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const raw = args.input ? await readFile(args.input, "utf8") : await readStdin();
  const payload = JSON.parse(raw);
  if (!payload.pr) throw new Error("payload missing required field 'pr'");

  // Stamp from a real Date (normal Node runtime; this is not a Workflow script).
  const now = new Date();
  const stampIso = now.toISOString();
  const stampFile = stampIso.replace(/[:.]/g, "-");

  await mkdir(OUTPUT_DIR, { recursive: true });
  const artifactPath = `automation/dep-validate/output/${payload.pr}-${stampFile}.md`;
  const absArtifact = resolve(repoRoot, artifactPath);
  const report = renderReport(payload, stampIso);
  await writeFile(absArtifact, report + "\n", "utf8");

  process.stdout.write(report + "\n");
  process.stderr.write(`Saved report to ${artifactPath}\n`);

  if (args.comment) {
    if (payload.classification !== "escalate") {
      process.stderr.write(
        "Skipping PR comment: classification is not 'escalate' (report artifact only).\n"
      );
    } else {
      const body = renderComment(payload, artifactPath);
      const res = await upsertComment(payload.pr, body);
      process.stderr.write(`PR #${payload.pr} comment ${res.action}.\n`);
    }
  }
}

await main();
