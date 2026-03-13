import { mkdir, writeFile } from "node:fs/promises";
import { extname, resolve } from "node:path";

import { buildTreeLines, listLabels } from "./page-source.mjs";

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, "-");
}

async function ensureOutputDir(outputDir) {
  await mkdir(outputDir, { recursive: true });
}

function sanitizeFilename(name, fallbackExtension) {
  const normalized = name.trim().replace(/[^A-Za-z0-9._-]+/g, "-");
  if (!normalized) {
    return `artifact-${timestamp()}${fallbackExtension}`;
  }

  if (extname(normalized)) {
    return normalized;
  }

  return `${normalized}${fallbackExtension}`;
}

export async function saveScreenshot(driver, outputDir, requestedName) {
  await ensureOutputDir(outputDir);
  const filename = requestedName
    ? sanitizeFilename(requestedName, ".png")
    : `wdio-explore-${timestamp()}.png`;
  const fullPath = resolve(outputDir, filename);
  await driver.saveScreenshot(fullPath);
  return fullPath;
}

export async function saveSource(driver, outputDir, requestedName, sourceOverride) {
  await ensureOutputDir(outputDir);
  const filename = requestedName
    ? sanitizeFilename(requestedName, ".xml")
    : `wdio-explore-${timestamp()}.xml`;
  const fullPath = resolve(outputDir, filename);
  await writeFile(fullPath, sourceOverride ?? await driver.getPageSource(), "utf8");
  return fullPath;
}

function stateLabel(state) {
  const mapping = {
    0: "not-installed",
    1: "not-running",
    2: "running-background-suspended",
    3: "running-background",
    4: "running-foreground"
  };
  return mapping[state] ?? `unknown-${state}`;
}

async function queryAppState(driver, bundleId) {
  const raw = await driver.execute("mobile: queryAppState", { bundleId });
  return {
    code: raw,
    label: stateLabel(raw)
  };
}

async function activateApp(driver, bundleId) {
  try {
    await driver.activateApp(bundleId);
  } catch (_) {
    await driver.execute("mobile: activateApp", { bundleId });
  }
}

function requireArg(args, index, usage) {
  if (args[index] == null || args[index] === "") {
    throw new Error(`Usage: ${usage}`);
  }
  return args[index];
}

function normalizeLimit(value, fallback) {
  const parsed = Number.parseInt(String(value ?? fallback), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

async function inspectUi(driver, outputDir, args) {
  const includeLabels = args.labels !== false;
  const includeTree = args.tree !== false;
  const includeSource = args.source === true;
  const includeScreenshot = args.screenshot === true;
  const limit = normalizeLimit(args.limit, 40);

  const needsSource = includeLabels || includeTree || includeSource;
  const source = needsSource ? await driver.getPageSource() : undefined;
  const artifacts = {};
  const result = {};

  if (includeLabels && source) {
    result.labels = listLabels(source, limit);
  }

  if (includeTree && source) {
    result.tree = buildTreeLines(source, limit);
  }

  if (includeSource && source) {
    artifacts.source = await saveSource(driver, outputDir, args.name, source);
  }

  if (includeScreenshot) {
    artifacts.screenshot = await saveScreenshot(driver, outputDir, args.name);
  }

  if (Object.keys(artifacts).length > 0) {
    result.artifacts = artifacts;
  }

  return result;
}

async function summarizeUi(driver, bundleId, args) {
  const source = await driver.getPageSource();
  const limit = normalizeLimit(args.limit, 20);
  return {
    appState: await queryAppState(driver, bundleId),
    labels: listLabels(source, limit)
  };
}

export async function runExplorerCommand(driver, context, command, args = {}) {
  const { bundleId, outputDir } = context;

  switch (command) {
    case "session.status":
      return {
        result: {
          bundleId,
          deviceName: context.deviceName,
          udid: context.udid,
          appState: await queryAppState(driver, bundleId)
        }
      };
    case "session.shutdown":
      return { result: "shutdown" };
    case "app.launch":
      await driver.execute("mobile: launchApp", { bundleId });
      return { result: await queryAppState(driver, bundleId) };
    case "app.activate":
      await activateApp(driver, bundleId);
      return { result: await queryAppState(driver, bundleId) };
    case "app.terminate":
      await driver.execute("mobile: terminateApp", { bundleId });
      return { result: await queryAppState(driver, bundleId) };
    case "app.state":
      return { result: await queryAppState(driver, bundleId) };
    case "ui.summary":
      return {
        result: await summarizeUi(driver, bundleId, args)
      };
    case "ui.inspect":
      return {
        result: await inspectUi(driver, outputDir, args)
      };
    case "ui.source": {
      const artifactPath = await saveSource(driver, outputDir, args.name);
      return {
        artifactPath,
        result: artifactPath
      };
    }
    case "ui.screenshot": {
      const artifactPath = await saveScreenshot(driver, outputDir, args.name);
      return {
        artifactPath,
        result: artifactPath
      };
    }
    case "ui.labels": {
      const source = await driver.getPageSource();
      return {
        result: listLabels(source, normalizeLimit(args.limit, 40))
      };
    }
    case "ui.tree": {
      const source = await driver.getPageSource();
      return {
        result: buildTreeLines(source, normalizeLimit(args.limit, 40))
      };
    }
    case "ui.exists": {
      const selector = requireArg([args.selector], 0, "ui.exists requires args.selector");
      const element = await driver.$(selector);
      return {
        result: await element.isExisting()
      };
    }
    case "ui.attr": {
      const selector = requireArg([args.selector], 0, "ui.attr requires args.selector");
      const attribute = requireArg([args.name], 0, "ui.attr requires args.name");
      const element = await driver.$(selector);
      return {
        result: await element.getAttribute(attribute)
      };
    }
    case "ui.tap": {
      const selector = requireArg([args.selector], 0, "ui.tap requires args.selector");
      const element = await driver.$(selector);
      await element.click();
      return { result: "tapped" };
    }
    case "ui.type": {
      const selector = requireArg([args.selector], 0, "ui.type requires args.selector");
      const text = requireArg([args.text], 0, "ui.type requires args.text");
      const element = await driver.$(selector);
      await element.setValue(text);
      return { result: "typed" };
    }
    case "ui.wait": {
      const selector = requireArg([args.selector], 0, "ui.wait requires args.selector");
      const timeout = normalizeLimit(args.timeoutMs, 10000);
      const element = await driver.$(selector);
      await element.waitForExist({ timeout });
      return { result: true };
    }
    default:
      throw new Error(`Unknown command '${command}'.`);
  }
}
