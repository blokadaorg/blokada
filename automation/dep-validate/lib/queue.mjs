import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const moduleDir = dirname(fileURLToPath(import.meta.url));
export const repoRoot = resolve(moduleDir, "..", "..", "..");

export const REPO = "blokadaorg/blokada";

// Ported verbatim from .github/workflows/dependabot-auto-merge.yml. Any changed
// path outside this allowlist is a human-review trigger there, so it is one here
// too. Keep in sync if the workflow's allowlist changes.
const ALLOWED_FILES_REGEX =
  /^(common\/pubspec\.(yaml|lock)|ios\/(Gemfile|Gemfile\.lock)|android\/(build\.gradle|settings\.gradle|gradle\.properties|gradle\/wrapper\/gradle-wrapper\.(jar|properties)|app\/build\.gradle)|ios\/BlockaWebExtension\/(package\.json|package-lock\.json)|automation\/appium\/wdio\/(package\.json|package-lock\.json)|\.github\/dependabot\.yml|\.github\/workflows\/[^/]+\.ya?ml)$/;

// Packages whose runtime behavior CI (build + lint only) cannot prove safe, so
// they warrant on-device validation regardless of bump size. Matched as a
// case-insensitive substring of the bumped package id. Each maps to the
// business surface the agent must judge for behavioral change (see SKILL.md).
const HIGH_RISK_PACKAGES = [
  { match: "adapty", surface: "payment" },
  { match: "firebase", surface: "messaging" },
  { match: "wireguard", surface: "protection" },
  { match: "pigeon", surface: "platform-bridge" },
  { match: "com.android.tools.build:gradle", surface: "build-system" },
  { match: "gradle-wrapper", surface: "build-system" },
  { match: "storekit", surface: "payment" }
];

// Numeric core (major[.minor[.patch]]) plus an optional pub prerelease/build
// suffix (e.g. 3.0.0-beta.1, 5.8.0+1). Without the suffix, a "from X to Y" line
// or a grouped-table cell carrying build metadata fails to match and the bump
// is silently dropped from the queue. majorOf() still keys off the leading int.
const VERSION =
  "v?\\d+(?:\\.\\d+){0,2}(?:[-+][0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?";

function gh(args) {
  return execFileSync("gh", args, {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024
  });
}

function majorOf(version) {
  const m = version.match(/^v?(\d+)/);
  return m ? m[1] : version;
}

// Extracts {pkg, from, to} bumps from a Dependabot title/body. Covers both
// single-bump "Bumps <pkg> from X to Y" lines (and the title) and the markdown
// table rows used in grouped PRs (| pkg | `from` | `to` |). The workflow only
// scans title + Bumps/Updates lines; grouped table parsing is the extension
// that lets the queue see majors hidden inside a group bump like #1082.
export function extractBumps(title, body) {
  const bumps = [];
  const seen = new Set();
  const add = (pkg, from, to) => {
    const key = `${pkg}@${from}->${to}`;
    if (seen.has(key)) return;
    seen.add(key);
    bumps.push({ pkg, from, to, major: majorOf(from) !== majorOf(to) });
  };

  // Grouped table rows. Scan ONLY the summary section above the first
  // <details> block: Dependabot puts its own bump table there, while the
  // release-note prose below contains compatibility/matrix tables whose rows
  // also look like "| lib | x | y |" and would otherwise be read as phantom
  // bumps. The workflow this ports from sidesteps this by scanning only
  // Bumps/Updates lines (see dependabot-auto-merge.yml comment).
  const summary = body.split(/<details/i)[0];
  const rowRe = new RegExp(
    `^\\|\\s*(?:\\[([^\\]]+)\\]\\([^)]*\\)|([^|]+?))\\s*\\|\\s*\`?(${VERSION})\`?\\s*\\|\\s*\`?(${VERSION})\`?\\s*\\|`,
    "gm"
  );
  for (const m of summary.matchAll(rowRe)) {
    const pkg = (m[1] ?? m[2] ?? "").trim();
    if (!pkg || pkg.toLowerCase() === "package") continue;
    add(pkg, m[3], m[4]);
  }

  // Title + "Bumps/Updates ..." body lines.
  const bumpLineRe = /^(?:Bumps|Updates) .*/gm;
  const lines = [title, ...(body.match(bumpLineRe) ?? [])];
  const fromToRe = new RegExp(`from (${VERSION}) to (${VERSION})`);
  for (const line of lines) {
    const ft = line.match(fromToRe);
    if (!ft) continue;
    let pkg = line.match(/\[([^\]]+)\]\([^)]+\)/)?.[1];
    if (!pkg) pkg = line.match(/`([^`]+)`/)?.[1];
    if (!pkg) pkg = line.match(/[Bb]umps? ([^\s]+) from/)?.[1];
    add(pkg ?? "(unknown package)", ft[1], ft[2]);
  }

  return bumps;
}

function highRiskHits(bumps) {
  const hits = [];
  for (const b of bumps) {
    const pkg = b.pkg.toLowerCase();
    for (const r of HIGH_RISK_PACKAGES) {
      if (pkg.includes(r.match)) hits.push({ pkg: b.pkg, surface: r.surface });
    }
  }
  return hits;
}

// Classifies one open Dependabot PR. Returns null when the PR would auto-merge
// (no major, only allowlisted files, no high-risk package) — i.e. nothing for
// the human/agent to validate.
function classifyPr(pr, detail) {
  const bumps = extractBumps(detail.title ?? "", detail.body ?? "");
  const majors = bumps.filter((b) => b.major);
  const risk = highRiskHits(bumps);
  const files = (detail.files ?? []).map((f) => f.path);
  const offlist = files.filter((f) => !ALLOWED_FILES_REGEX.test(f));

  const reasons = [];
  if (majors.length) {
    reasons.push(
      `major version bump: ${majors
        .map((b) => `${b.pkg} ${b.from}→${b.to}`)
        .join(", ")}`
    );
  }
  if (risk.length) {
    reasons.push(
      `high-risk package: ${[...new Set(risk.map((r) => r.pkg))].join(", ")}`
    );
  }
  if (offlist.length) {
    reasons.push(`touches non-dependency file(s): ${offlist.join(", ")}`);
  }
  // No github-actions carve-out: dependabot-auto-merge.yml dropped its
  // "human review required (supply-chain risk)" branch-prefix case in #1115,
  // so action bumps flow through the same path as every other ecosystem and
  // the major-bump gate above is the one real guard. Dependabot only bumps an
  // action already in the repo, so a bump cannot introduce a new publisher.
  // Re-adding a reason here would queue every patch/minor action bump that the
  // workflow auto-merges anyway.

  if (!reasons.length) return null;

  return {
    kind: "dependabot-pr",
    pr: pr.number,
    title: detail.title ?? pr.title,
    branch: pr.headRefName,
    ecosystem: pr.headRefName.split("/")[1] ?? "unknown",
    reasons,
    majors,
    highRiskPackages: [...new Set(risk.map((r) => r.pkg))],
    surfaces: [...new Set(risk.map((r) => r.surface))],
    offlistFiles: offlist
  };
}

export function discoverDependabotQueue() {
  const prs = JSON.parse(
    gh([
      "pr",
      "list",
      "--repo",
      REPO,
      "--author",
      "app/dependabot",
      "--state",
      "open",
      "--limit",
      "100",
      "--json",
      "number,title,headRefName"
    ])
  );

  const queue = [];
  for (const pr of prs) {
    try {
      const detail = JSON.parse(
        gh([
          "pr",
          "view",
          String(pr.number),
          "--repo",
          REPO,
          "--json",
          "title,body,files"
        ])
      );
      const entry = classifyPr(pr, detail);
      if (entry) queue.push(entry);
    } catch (error) {
      // A transient API error on one PR must not discard the rest of the
      // queue. Surface it as an error entry so a headless run still reports.
      process.stderr.write(
        `dep-validate: failed to classify PR #${pr.number}: ${
          error?.message ?? error
        }\n`
      );
      queue.push({
        kind: "dependabot-pr",
        pr: pr.number,
        title: pr.title,
        branch: pr.headRefName,
        error: "classification failed; inspect this PR manually"
      });
    }
  }
  return queue;
}

// Unscanned ecosystems have no PR to check out, so these are advisory only:
// the agent surfaces version drift, it does not run the build/validate loop.
export function discoverAdvisories() {
  const advisories = [];

  // Git submodules: compare pinned SHA to upstream default-branch HEAD.
  const status = (() => {
    try {
      return execFileSync("git", ["submodule", "status"], {
        cwd: repoRoot,
        encoding: "utf8"
      });
    } catch {
      return "";
    }
  })();
  for (const line of status.split("\n")) {
    const m = line.trim().match(/^[-+ U]?([0-9a-f]{7,40})\s+(\S+)/);
    if (!m) continue;
    const [, current, path] = m;
    // Only the dependency submodules called out in the issue.
    if (!/wireguard-apple|translate/.test(path)) continue;
    let latest = "";
    try {
      const url = execFileSync(
        "git",
        ["config", "-f", ".gitmodules", `submodule.${path}.url`],
        { cwd: repoRoot, encoding: "utf8" }
      ).trim();
      const head = execFileSync("git", ["ls-remote", url, "HEAD"], {
        cwd: repoRoot,
        encoding: "utf8"
      });
      latest = head.split(/\s+/)[0] ?? "";
    } catch {
      latest = "";
    }
    advisories.push({
      kind: "advisory",
      ecosystem: "submodule",
      subject: path,
      current,
      latest,
      differsFromUpstreamHead: latest !== "" && latest !== current,
      note: "not scanned by Dependabot; bump the submodule pointer manually"
    });
  }

  // iOS Swift Package Manager: not Dependabot-scanned. Surface current pins of
  // the host SPM packages (Firebase, Factory, CodeScanner) so the agent can
  // compare them to upstream releases manually (latest-version lookup is left
  // to the agent). Adapty's iOS version is governed by adapty_flutter in
  // common/pubspec.yaml, which Dependabot does scan, so it's covered above.
  try {
    const pbxproj = readFileSync(
      resolve(repoRoot, "ios/IOS.xcodeproj/project.pbxproj"),
      "utf8"
    );
    // Only the package references listed in the project's `packageReferences`
    // array are live; the file also carries orphaned duplicate references from
    // past Xcode edits (e.g. several stale Factory pins) that we must ignore.
    const listed = pbxproj.match(/packageReferences = \(([\s\S]*?)\);/);
    const active = new Set(
      listed ? [...listed[1].matchAll(/([0-9A-F]{24})/g)].map((m) => m[1]) : []
    );
    const re =
      /([0-9A-F]{24}) \/\* [^*]*\*\/ = \{\s*isa = XCRemoteSwiftPackageReference;\s*repositoryURL = "([^"]+)";\s*requirement = \{[^}]*?(?:minimumVersion|version) = ([^;]+);/g;
    let m;
    while ((m = re.exec(pbxproj)) !== null) {
      if (active.size && !active.has(m[1])) continue;
      const name = m[2].replace(/\.git$/, "").split("/").pop();
      advisories.push({
        kind: "advisory",
        ecosystem: "swift-package-manager",
        subject: `ios SPM: ${name}`,
        current: m[3].trim(),
        note: "not scanned by Dependabot; compare to upstream release manually"
      });
    }
  } catch {
    // project.pbxproj unreadable in this checkout; skip.
  }

  return advisories;
}
