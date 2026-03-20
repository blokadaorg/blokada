import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";

const moduleDir = dirname(fileURLToPath(import.meta.url));
const automationRoot = resolve(moduleDir, "..", "..");
const repoRoot = resolve(automationRoot, "..");

const APP_GROUP_ID = "group.net.blocka.app";
const DEFAULT_WINDOW = "1h";
const DEFAULT_LINES = 400;
const MAX_LINES = 1000;
const TIMESTAMP_REGEX = /\b(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\b/;
const SECTION_START_REGEX = /^\s*[A-Z]+\s+┌/;
const SYSTEM_CRASH_LOGS_DOMAIN = "systemCrashLogs";

function formatError(error, fallback) {
  if (!(error instanceof Error)) {
    return fallback;
  }

  const stdout = typeof error.stdout === "string" ? error.stdout.trim() : "";
  const stderr = typeof error.stderr === "string" ? error.stderr.trim() : "";
  return stderr || stdout || error.message || fallback;
}

function makeLocalDate(timestamp) {
  const match = timestamp.match(
    /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/
  );
  if (!match) {
    return undefined;
  }

  const [, year, month, day, hour, minute, second] = match;
  return new Date(
    Number.parseInt(year, 10),
    Number.parseInt(month, 10) - 1,
    Number.parseInt(day, 10),
    Number.parseInt(hour, 10),
    Number.parseInt(minute, 10),
    Number.parseInt(second, 10)
  );
}

export function getDeviceLogOutputDir() {
  return resolve(repoRoot, "automation", "device", "output", "logs");
}

export function getDeviceCrashOutputDir() {
  return resolve(repoRoot, "automation", "device", "output", "crashlogs");
}

export function normalizeWindow(window = DEFAULT_WINDOW) {
  const normalized = String(window).trim().toLowerCase();
  if (normalized === "" || normalized === DEFAULT_WINDOW) {
    return DEFAULT_WINDOW;
  }
  if (normalized === "today") {
    return "today";
  }
  throw new Error(`Unsupported log window '${window}'. Expected '1h' or 'today'.`);
}

export function normalizeLines(lines = DEFAULT_LINES) {
  const parsed = Number.parseInt(String(lines), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return DEFAULT_LINES;
  }
  return Math.min(parsed, MAX_LINES);
}

export function getShareLogPrefix(bundleId = "net.blocka.app") {
  if (bundleId === "net.blocka.app.family" || bundleId.endsWith(".family")) {
    return "blokada-iFx";
  }

  if (bundleId === "net.blocka.app") {
    return "blokada-i6x";
  }

  throw new Error(`Unsupported bundle id '${bundleId}' for share-log lookup.`);
}

export function getDeviceLogArtifactBaseName(bundleId, window) {
  return `${getShareLogPrefix(bundleId)}-${normalizeWindow(window)}`;
}

export function getCrashReportPrefix(bundleId = "net.blocka.app") {
  if (bundleId === "net.blocka.app.family" || bundleId.endsWith(".family")) {
    return "FamilyDev-";
  }

  if (bundleId === "net.blocka.app") {
    return "Dev-";
  }

  throw new Error(
    `Unsupported bundle id '${bundleId}' for crash-report lookup. Only Blokada 6 and Blokada Family are supported.`
  );
}

export function selectNewestCrashReport(files, bundleId) {
  const prefix = getCrashReportPrefix(bundleId);
  const matches = files.filter((file) => {
    const name = file?.name ?? file?.relativePath ?? "";
    const isDirectory = file?.resources?.isDirectory === true;
    return !isDirectory && name.startsWith(prefix) && name.endsWith(".ips");
  });

  matches.sort((left, right) => {
    const leftDate = Date.parse(left?.metadata?.lastModDate ?? "") || 0;
    const rightDate = Date.parse(right?.metadata?.lastModDate ?? "") || 0;
    return rightDate - leftDate;
  });

  return matches[0];
}

export function selectNewestLogFile(files, bundleId) {
  const prefix = getShareLogPrefix(bundleId);
  const matches = files.filter((file) => {
    const name = file?.name ?? file?.relativePath ?? "";
    const isDirectory = file?.resources?.isDirectory === true;
    return !isDirectory && name.startsWith(prefix) && name.endsWith(".log");
  });

  matches.sort((left, right) => {
    const leftDate = Date.parse(left?.metadata?.lastModDate ?? "") || 0;
    const rightDate = Date.parse(right?.metadata?.lastModDate ?? "") || 0;
    return rightDate - leftDate;
  });

  return matches[0];
}

export function parseTimestampFromLine(line) {
  const match = String(line).match(TIMESTAMP_REGEX);
  if (!match) {
    return undefined;
  }

  return makeLocalDate(match[1]);
}

export function filterLogText(text, options = {}) {
  const window = normalizeWindow(options.window);
  const linesLimit = normalizeLines(options.lines);
  const now = options.now instanceof Date ? options.now : new Date();
  const cutoff =
    window === "today"
      ? new Date(now.getFullYear(), now.getMonth(), now.getDate())
      : new Date(now.getTime() - (60 * 60 * 1000));

  const inputLines = String(text).split(/\r?\n/);
  const sections = [];
  let current = {
    lines: [],
    timestamp: undefined
  };

  for (const line of inputLines) {
    if (SECTION_START_REGEX.test(line) && current.lines.length > 0) {
      sections.push(current);
      current = { lines: [], timestamp: undefined };
    }

    current.lines.push(line);
    const timestamp = parseTimestampFromLine(line);
    if (timestamp) {
      current.timestamp = timestamp;
    }
  }

  if (current.lines.length > 0) {
    sections.push(current);
  }

  const keptLines = [];
  let previousTimestampedSectionKept = false;

  for (const section of sections) {
    if (section.timestamp) {
      previousTimestampedSectionKept = section.timestamp >= cutoff;
      if (previousTimestampedSectionKept) {
        keptLines.push(...section.lines);
      }
      continue;
    }

    if (previousTimestampedSectionKept) {
      keptLines.push(...section.lines);
    }
  }

  while (keptLines.length > 0 && keptLines[0] === "") {
    keptLines.shift();
  }
  while (keptLines.length > 0 && keptLines[keptLines.length - 1] === "") {
    keptLines.pop();
  }

  const limitedLines =
    keptLines.length > linesLimit
      ? keptLines.slice(keptLines.length - linesLimit)
      : keptLines;

  return {
    window,
    lineCount: keptLines.length,
    returnedLineCount: limitedLines.length,
    text: limitedLines.join("\n")
  };
}

async function runDevicectlJson(args, execFileSyncImpl = execFileSync) {
  const tempDir = await mkdtemp(join(tmpdir(), "blokada-devicectl-json-"));
  const jsonPath = join(tempDir, "result.json");

  try {
    execFileSyncImpl("xcrun", [...args, "--json-output", jsonPath], {
      encoding: "utf8"
    });
    const payload = await readFile(jsonPath, "utf8");
    return JSON.parse(payload);
  } catch (error) {
    throw new Error(formatError(error, "devicectl command failed."));
  } finally {
    await rm(tempDir, { recursive: true, force: true });
  }
}

async function listAppGroupFiles(device, execFileSyncImpl = execFileSync) {
  const payload = await runDevicectlJson(
    [
      "devicectl",
      "device",
      "info",
      "files",
      "--device",
      device.udid,
      "--domain-type",
      "appGroupDataContainer",
      "--domain-identifier",
      APP_GROUP_ID,
      "--subdirectory",
      "."
    ],
    execFileSyncImpl
  );

  return payload?.result?.files ?? [];
}

async function listSystemCrashLogs(device, execFileSyncImpl = execFileSync) {
  const payload = await runDevicectlJson(
    [
      "devicectl",
      "device",
      "info",
      "files",
      "--device",
      device.udid,
      "--domain-type",
      SYSTEM_CRASH_LOGS_DOMAIN,
      "--subdirectory",
      "."
    ],
    execFileSyncImpl
  );

  return payload?.result?.files ?? [];
}

async function copyRemoteFile(
  device,
  sourceFile,
  destination,
  execFileSyncImpl = execFileSync,
  domainType = "appGroupDataContainer",
  domainIdentifier = domainType === "appGroupDataContainer" ? APP_GROUP_ID : undefined
) {
  const args = [
    "devicectl",
    "device",
    "copy",
    "from",
    "--device",
    device.udid,
    "--domain-type",
    domainType
  ];
  if (domainIdentifier) {
    args.push("--domain-identifier", domainIdentifier);
  }
  args.push("--source", sourceFile, "--destination", destination);

  try {
    execFileSyncImpl("xcrun", args, { encoding: "utf8" });
  } catch (error) {
    throw new Error(formatError(error, `Failed to copy '${sourceFile}' from device.`));
  }
}

export async function pullRecentDeviceLog(options) {
  const {
    bundleId = "net.blocka.app",
    device,
    execFileSyncImpl = execFileSync,
    lines = DEFAULT_LINES,
    now = new Date(),
    outputDir = getDeviceLogOutputDir(),
    save = true,
    window = DEFAULT_WINDOW
  } = options;

  if (!device?.udid) {
    throw new Error("Missing device information for recent-log retrieval.");
  }

  const effectiveWindow = normalizeWindow(window);
  const effectiveLines = normalizeLines(lines);
  const files = await listAppGroupFiles(device, execFileSyncImpl);
  const sourceFile = selectNewestLogFile(files, bundleId);

  if (!sourceFile?.relativePath) {
    throw new Error(
      `No share log file matching '${getShareLogPrefix(bundleId)}*.log' was found in app group ${APP_GROUP_ID}.`
    );
  }

  await mkdir(outputDir, { recursive: true });

  const baseName = getDeviceLogArtifactBaseName(bundleId, effectiveWindow);
  const fullArtifactPath = resolve(outputDir, `${baseName}.full.log`);
  const artifactPath = resolve(outputDir, `${baseName}.log`);

  await copyRemoteFile(device, sourceFile.relativePath, fullArtifactPath, execFileSyncImpl);
  const fullText = await readFile(fullArtifactPath, "utf8");
  const filtered = filterLogText(fullText, {
    lines: effectiveLines,
    now,
    window: effectiveWindow
  });

  if (save) {
    await writeFile(artifactPath, filtered.text, "utf8");
  }

  return {
    artifactPath: save ? artifactPath : undefined,
    fullArtifactPath,
    lineCount: filtered.lineCount,
    returnedLineCount: filtered.returnedLineCount,
    sourceFile: sourceFile.relativePath,
    text: filtered.text,
    window: filtered.window
  };
}

export async function pullRecentCrashReport(options) {
  const {
    bundleId = "net.blocka.app",
    device,
    execFileSyncImpl = execFileSync,
    outputDir = getDeviceCrashOutputDir(),
    save = true
  } = options;

  if (!device?.udid) {
    throw new Error("Missing device information for crash-report retrieval.");
  }

  const files = await listSystemCrashLogs(device, execFileSyncImpl);
  const sourceFile = selectNewestCrashReport(files, bundleId);

  if (!sourceFile?.name) {
    throw new Error(
      `No crash report matching '${getCrashReportPrefix(bundleId)}*.ips' was found in ${SYSTEM_CRASH_LOGS_DOMAIN}.`
    );
  }

  await mkdir(outputDir, { recursive: true });

  const artifactPath = resolve(outputDir, sourceFile.name);
  await copyRemoteFile(
    device,
    sourceFile.name,
    artifactPath,
    execFileSyncImpl,
    SYSTEM_CRASH_LOGS_DOMAIN
  );
  const text = await readFile(artifactPath, "utf8");

  if (!save) {
    await rm(artifactPath, { force: true });
  }

  return {
    artifactPath: save ? artifactPath : undefined,
    sourceFile: sourceFile.name,
    text
  };
}
