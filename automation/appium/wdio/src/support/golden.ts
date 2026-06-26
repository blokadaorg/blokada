import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { driver } from "@wdio/globals";
import pixelmatch from "pixelmatch";
import { PNG } from "pngjs";

import { ensureDirectory } from "./files.js";

// The WDIO process runs with cwd = automation/appium/wdio (see `make
// appium-test`). Goldens live next to the specs and are committed to git;
// transient diff/actual images go to the shared output dir CI uploads.
const goldenDir = resolve(process.cwd(), "src", "specs", "smoke", "__golden__");
const outputDir = resolve(process.cwd(), "..", "output");

export interface GoldenOptions {
  /** Max fraction of differing pixels tolerated before failing (default 0.02). */
  maxDiffRatio?: number;
  /** Top band masked out to ignore the status bar (clock/battery). 0..1, default 0.06. */
  maskTopRatio?: number;
  /** Extra rectangles to mask, expressed as 0..1 fractions of width/height. */
  maskRegions?: Array<{ x: number; y: number; w: number; h: number }>;
  /** Per-pixel colour delta sensitivity passed to pixelmatch (default 0.1). */
  threshold?: number;
}

function maskRect(png: PNG, x: number, y: number, w: number, h: number): void {
  const x0 = Math.max(0, Math.round(x));
  const y0 = Math.max(0, Math.round(y));
  const x1 = Math.min(png.width, Math.round(x + w));
  const y1 = Math.min(png.height, Math.round(y + h));
  for (let row = y0; row < y1; row++) {
    for (let col = x0; col < x1; col++) {
      const idx = (png.width * row + col) << 2;
      png.data[idx] = 0;
      png.data[idx + 1] = 0;
      png.data[idx + 2] = 0;
      png.data[idx + 3] = 255;
    }
  }
}

function applyMasks(png: PNG, options: GoldenOptions): void {
  const maskTopRatio = options.maskTopRatio ?? 0.06;
  if (maskTopRatio > 0) {
    maskRect(png, 0, 0, png.width, png.height * maskTopRatio);
  }
  for (const region of options.maskRegions ?? []) {
    maskRect(
      png,
      region.x * png.width,
      region.y * png.height,
      region.w * png.width,
      region.h * png.height
    );
  }
}

function writePng(path: string, png: PNG): void {
  ensureDirectory(path);
  writeFileSync(path, PNG.sync.write(png));
}

/** `paywall.png` + `actual` -> `output/paywall-actual.png` (no double extension). */
function artifactPath(name: string, suffix: string): string {
  return resolve(outputDir, `${name.replace(/\.png$/i, "")}-${suffix}.png`);
}

/**
 * Capture the current screen and compare it to a committed golden image.
 *
 * Strict: throws when the masked diff exceeds `maxDiffRatio`, when dimensions
 * differ, or when no golden exists. Set `UPDATE_GOLDEN=1` to (re)generate the
 * golden from the current screen instead of comparing — needed for the first
 * baseline and after any intentional paywall change.
 */
export async function compareToGolden(
  name: string,
  options: GoldenOptions = {}
): Promise<void> {
  const goldenPath = resolve(goldenDir, name);
  const actualPng = PNG.sync.read(
    Buffer.from(await driver.takeScreenshot(), "base64")
  );

  if (process.env.UPDATE_GOLDEN === "1") {
    writePng(goldenPath, actualPng);
    console.warn(`Golden updated: ${goldenPath} (UPDATE_GOLDEN=1)`);
    return;
  }

  if (!existsSync(goldenPath)) {
    const actualPath = artifactPath(name, "actual");
    writePng(actualPath, actualPng);
    throw new Error(
      `No golden for "${name}". Inspect ${actualPath}, then commit a baseline ` +
        `by rerunning with UPDATE_GOLDEN=1.`
    );
  }

  const goldenPng = PNG.sync.read(readFileSync(goldenPath));
  if (goldenPng.width !== actualPng.width || goldenPng.height !== actualPng.height) {
    const actualPath = artifactPath(name, "actual");
    writePng(actualPath, actualPng);
    throw new Error(
      `Golden ${goldenPng.width}x${goldenPng.height} != actual ` +
        `${actualPng.width}x${actualPng.height} for "${name}". Device or ` +
        `orientation changed; regenerate with UPDATE_GOLDEN=1.`
    );
  }

  applyMasks(goldenPng, options);
  applyMasks(actualPng, options);

  const { width, height } = goldenPng;
  const diff = new PNG({ width, height });
  const numDiffPixels = pixelmatch(
    goldenPng.data,
    actualPng.data,
    diff.data,
    width,
    height,
    { threshold: options.threshold ?? 0.1 }
  );
  const ratio = numDiffPixels / (width * height);
  const maxDiffRatio = options.maxDiffRatio ?? 0.02;

  if (ratio > maxDiffRatio) {
    const diffPath = artifactPath(name, "diff");
    const actualPath = artifactPath(name, "actual");
    writePng(diffPath, diff);
    writePng(actualPath, actualPng);
    throw new Error(
      `Golden mismatch for "${name}": ${(ratio * 100).toFixed(2)}% pixels ` +
        `differ (max ${(maxDiffRatio * 100).toFixed(2)}%). See ${diffPath} and ` +
        `${actualPath}. If this is an intentional change, regenerate with ` +
        `UPDATE_GOLDEN=1.`
    );
  }

  console.warn(
    `Golden match for "${name}": ${(ratio * 100).toFixed(2)}% diff ` +
      `(<= ${(maxDiffRatio * 100).toFixed(2)}%).`
  );
}
