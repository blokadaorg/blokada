import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { driver } from "@wdio/globals";

import { ensureDirectory } from "./files.js";

const outputDir = resolve(process.cwd(), "..", "output");

// Set while the screen may show sensitive data (the Private DNS hostname,
// which carries the device tag). Android skips screenshots and page source
// then, since CI uploads them from a public repo. iOS keeps its existing
// capture behaviour.
let sensitiveScreen = false;

export function setSensitiveScreen(value: boolean): void {
  sensitiveScreen = value;
}

function captureSuppressed(kind: string, name: string): boolean {
  if (!sensitiveScreen || !driver.isAndroid) {
    return false;
  }
  console.warn(`Skipping ${kind} '${name}': the screen may show an account id.`);
  return true;
}

function artifactPath(filename: string): string {
  const fullPath = resolve(outputDir, filename);
  ensureDirectory(fullPath);
  return fullPath;
}

export async function saveScreenshot(name: string): Promise<string> {
  const path = artifactPath(name);
  if (captureSuppressed("screenshot", name)) {
    return path;
  }
  await driver.saveScreenshot(path);
  return path;
}

export async function savePageSource(name: string): Promise<string> {
  const path = artifactPath(name);
  if (captureSuppressed("page source", name)) {
    return path;
  }
  const source = await driver.getPageSource();
  writeFileSync(path, source, { encoding: "utf8" });
  return path;
}

export async function saveSyslog(name: string): Promise<string | undefined> {
  // Android has logcat instead, which can carry the Private DNS hostname; the
  // Android run does not collect device logs.
  if (driver.isAndroid) {
    return undefined;
  }
  try {
    const path = artifactPath(name);
    const logs = (await driver.getLogs("syslog")) as Array<{
      message: string;
      level?: string;
      timestamp: number;
    }>;
    const payload = logs
      .map((entry) => {
        const timestamp = new Date(entry.timestamp).toISOString();
        return `[${timestamp}] ${entry.level?.toUpperCase() ?? "INFO"} ${entry.message}`;
      })
      .join("\n");
    writeFileSync(path, payload, { encoding: "utf8" });
    return path;
  } catch (error) {
    console.warn(`Failed to capture syslog: ${String(error)}`);
    return undefined;
  }
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
}

export function registerFailureArtifacts(): void {
  afterEach(async function registerArtifactsForFailure() {
    if (this.currentTest?.state !== "failed") {
      return;
    }
    const slug = slugify(this.currentTest.fullTitle());
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const baseName = `${timestamp}-${slug}`;

    try {
      await saveScreenshot(`${baseName}.png`);
    } catch (error) {
      console.warn(`Failed to save failure screenshot: ${String(error)}`);
    }

    try {
      await savePageSource(`${baseName}.xml`);
    } catch (error) {
      console.warn(`Failed to save page source: ${String(error)}`);
    }

    await saveSyslog(`${baseName}.log`);
  });
}
