import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { driver } from "@wdio/globals";

import { ensureDirectory } from "./files.js";

const outputDir = resolve(process.cwd(), "..", "output");

function artifactPath(filename: string): string {
  const fullPath = resolve(outputDir, filename);
  ensureDirectory(fullPath);
  return fullPath;
}

export async function saveScreenshot(name: string): Promise<string> {
  const path = artifactPath(name);
  await driver.saveScreenshot(path);
  return path;
}

export async function savePageSource(name: string): Promise<string> {
  const path = artifactPath(name);
  const source = await driver.getPageSource();
  writeFileSync(path, source, { encoding: "utf8" });
  return path;
}

export async function saveSyslog(name: string): Promise<string | undefined> {
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
