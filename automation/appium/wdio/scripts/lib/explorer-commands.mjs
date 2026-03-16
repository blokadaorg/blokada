import { mkdir, writeFile } from "node:fs/promises";
import { extname, resolve } from "node:path";

import { buildKnownAppTargets } from "./app-targets.mjs";
import {
  buildTreeLines,
  getApplicationIdentity,
  listLabels,
  listVisibleElements
} from "./page-source.mjs";

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

async function getActiveAppInfo(driver) {
  try {
    const activeApp = await driver.execute("mobile: activeAppInfo");
    return activeApp && typeof activeApp === "object" ? activeApp : undefined;
  } catch (_) {
    return undefined;
  }
}

async function activateApp(driver, bundleId) {
  try {
    await driver.activateApp(bundleId);
  } catch (_) {
    await driver.execute("mobile: activateApp", { bundleId });
  }
}

async function waitForVerifiedForegroundTarget(driver, context, bundleId, timeoutMs = 3000) {
  const deadline = Date.now() + timeoutMs;
  let appState = await queryAppState(driver, bundleId);
  let foreground = await getForegroundTarget(driver, context);

  while (
    Date.now() < deadline &&
    !(
      appState.code === 4 &&
      (!foreground.verified || foreground.target.bundleId === bundleId)
    )
  ) {
    await new Promise((resolve) => setTimeout(resolve, 250));
    appState = await queryAppState(driver, bundleId);
    foreground = await getForegroundTarget(driver, context);
  }

  return {
    appState,
    foreground
  };
}

function buildKnownTargets(context) {
  return buildKnownAppTargets();
}

function getSessionTarget(context) {
  return findTargetByBundleId(context, context.bundleId) ?? toExternalTarget(context.bundleId);
}

function getActiveTarget(context) {
  return context.activeTarget ?? getSessionTarget(context);
}

function setActiveTarget(context, target) {
  context.activeTarget = {
    name: target.name,
    bundleId: target.bundleId,
    aliases: [...(target.aliases ?? [])]
  };
}

function resolveTarget(context, args = {}, { fallbackToActive = false } = {}) {
  const knownTargets = buildKnownTargets(context);
  const bundleId = typeof args.bundleId === "string" ? args.bundleId.trim() : "";
  if (bundleId.length > 0) {
    const alias = typeof args.target === "string" ? args.target.trim().toLowerCase() : "custom";
    return {
      name: alias || "custom",
      aliases: alias ? [alias] : [],
      bundleId
    };
  }

  const targetName = typeof args.target === "string" ? args.target.trim().toLowerCase() : "";
  if (!targetName) {
    return fallbackToActive ? getActiveTarget(context) : getSessionTarget(context);
  }

  const matched = knownTargets.find((target) =>
    target.name === targetName || target.aliases.includes(targetName)
  );
  if (matched) {
    return matched;
  }

  const supportedTargets = knownTargets.map((target) => target.name).join(", ");
  throw new Error(
    `Unknown app target '${args.target}'. Use one of: ${supportedTargets}, or provide args.bundleId.`
  );
}

function withTargetMetadata(target, payload) {
  return {
    target: target.name,
    bundleId: target.bundleId,
    ...payload
  };
}

function findTargetByBundleId(context, bundleId) {
  return buildKnownTargets(context).find((target) => target.bundleId === bundleId);
}

function toExternalTarget(bundleId) {
  return {
    name: "external",
    aliases: [],
    bundleId
  };
}

async function getForegroundTarget(driver, context) {
  const activeApp = await getActiveAppInfo(driver);
  const activeBundleId =
    typeof activeApp?.bundleId === "string" && activeApp.bundleId.trim().length > 0
      ? activeApp.bundleId.trim()
      : undefined;

  if (activeBundleId) {
    const matchedTarget = findTargetByBundleId(context, activeBundleId);
    if (matchedTarget) {
      setActiveTarget(context, matchedTarget);
      return {
        activeApp,
        target: matchedTarget,
        verified: true
      };
    }

    return {
      activeApp,
      target: toExternalTarget(activeBundleId),
      verified: true
    };
  }

  return {
    activeApp,
    target: getActiveTarget(context),
    verified: false
  };
}

async function describeKnownTargets(driver, context) {
  const foreground = await getForegroundTarget(driver, context);
  const targets = await Promise.all(
    buildKnownTargets(context).map(async (target) =>
      withTargetMetadata(target, {
        aliases: target.aliases,
        appState: await queryAppState(driver, target.bundleId)
      })
    )
  );

  return {
    activeTarget: foreground.target.name,
    targets
  };
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

function buildInspectOptions(args = {}) {
  return {
    compact: args.compact === true,
    interactiveOnly: args.interactiveOnly === true,
    visibleOnly: args.visibleOnly === true,
    matchText: args.matchText
  };
}

async function inspectUi(driver, outputDir, args) {
  const includeLabels = args.labels !== false;
  const includeTree = args.tree !== false;
  const includeElements = args.elements !== false;
  const includeSource = args.source === true;
  const includeScreenshot = args.screenshot === true;
  const limit = normalizeLimit(args.limit, 40);
  const inspectOptions = buildInspectOptions(args);

  const needsSource = includeLabels || includeTree || includeElements || includeSource;
  const source = needsSource ? await driver.getPageSource() : undefined;
  const artifacts = {};
  const result = {};

  if (includeLabels && source) {
    result.labels = listLabels(source, limit, inspectOptions);
  }

  if (includeTree && source) {
    result.tree = buildTreeLines(source, limit, inspectOptions);
  }

  if (includeElements && source) {
    result.elements = listVisibleElements(source, limit, inspectOptions);
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

function normalizeDirection(value, fallback = "down") {
  const normalized = String(value ?? fallback)
    .trim()
    .toLowerCase();
  if (["up", "down", "left", "right"].includes(normalized)) {
    return normalized;
  }
  throw new Error(`Unsupported direction '${value}'. Use up, down, left, or right.`);
}

function normalizeBooleanValue(value) {
  if (typeof value !== "string") {
    return undefined;
  }

  const normalized = value.trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) {
    return true;
  }
  if (["0", "false", "no", "off"].includes(normalized)) {
    return false;
  }
  return undefined;
}

async function readElementState(element, attributes = []) {
  const attributeNames =
    attributes.length > 0
      ? [...new Set(attributes)]
      : ["name", "label", "value", "type", "enabled", "visible", "hittable", "selected"];
  const state = {};

  for (const attribute of attributeNames) {
    const value = await element.getAttribute(attribute);
    if (value != null) {
      state[attribute] = value;
    }
  }

  state.booleanValue = normalizeBooleanValue(state.value);
  state.enabledBoolean = normalizeBooleanValue(state.enabled);
  state.visibleBoolean = normalizeBooleanValue(state.visible);
  state.hittableBoolean = normalizeBooleanValue(state.hittable);
  state.selectedBoolean = normalizeBooleanValue(state.selected);

  return state;
}

async function findSearchField(driver, selector) {
  const searchSelector =
    typeof selector === "string" && selector.trim().length > 0
      ? selector.trim()
      : "//XCUIElementTypeSearchField[1]";
  const element = await driver.$(searchSelector);
  if (!(await element.isExisting())) {
    throw new Error(`No search field matched selector '${searchSelector}'.`);
  }
  return {
    element,
    selector: searchSelector
  };
}

async function focusSearchField(driver, args) {
  const { element, selector } = await findSearchField(driver, args.selector);
  await element.click();
  return {
    element,
    selector
  };
}

async function searchInUi(driver, args) {
  const text = requireArg([args.text], 0, "ui.search requires args.text");
  const { element, selector } = await focusSearchField(driver, args);
  if (args.append !== true) {
    try {
      await element.clearValue();
    } catch (_) {
      // Some controls do not expose clearValue; setValue still replaces content in practice.
    }
  }
  await element.setValue(text);
  return {
    selector,
    text
  };
}

async function navigateBack(driver) {
  try {
    await driver.back();
    return "driver.back";
  } catch (_) {
    const selector = "//XCUIElementTypeNavigationBar[1]/XCUIElementTypeButton[1]";
    const element = await driver.$(selector);
    if (!(await element.isExisting())) {
      throw new Error("No back navigation control is available in the current view.");
    }
    await element.click();
    return selector;
  }
}

async function summarizeUi(driver, context, args) {
  const source = await driver.getPageSource();
  const limit = normalizeLimit(args.limit, 20);
  const inspectOptions = buildInspectOptions(args);
  const foreground = await getForegroundTarget(driver, context);
  return {
    appIdentity: getApplicationIdentity(source),
    activeApp: foreground.activeApp,
    appState: await queryAppState(driver, foreground.target.bundleId),
    labels: listLabels(source, limit, inspectOptions),
    targetVerified: foreground.verified
  };
}

export async function runExplorerCommand(driver, context, command, args = {}) {
  const { bundleId, outputDir } = context;

  switch (command) {
    case "session.status":
      {
        const foreground = await getForegroundTarget(driver, context);
        return {
          result: {
            bundleId,
            ...(await describeKnownTargets(driver, context)),
            deviceName: context.deviceName,
            udid: context.udid,
            activeApp: foreground.activeApp,
            appState: await queryAppState(driver, foreground.target.bundleId)
          }
        };
      }
    case "session.shutdown":
      return { result: "shutdown" };
    case "app.targets":
      return {
        result: await describeKnownTargets(driver, context)
      };
    case "app.launch": {
      const target = resolveTarget(context, args);
      await driver.execute("mobile: launchApp", { bundleId: target.bundleId });
      const { appState, foreground } = await waitForVerifiedForegroundTarget(
        driver,
        context,
        target.bundleId
      );
      if (appState.code !== 4) {
        throw new Error(
          `Launch did not bring ${target.bundleId} to foreground (state=${appState.label}).`
        );
      }
      if (foreground.verified && foreground.target.bundleId !== target.bundleId) {
        throw new Error(
          `Launch foreground verification failed for ${target.bundleId}; active app is ${foreground.target.bundleId}.`
        );
      }
      setActiveTarget(context, target);
      return {
        result: withTargetMetadata(target, {
          ...appState,
          activeApp: foreground.activeApp,
          targetVerified: foreground.verified
        })
      };
    }
    case "app.activate": {
      const target = resolveTarget(context, args);
      await activateApp(driver, target.bundleId);
      const { appState, foreground } = await waitForVerifiedForegroundTarget(
        driver,
        context,
        target.bundleId
      );
      if (appState.code !== 4) {
        throw new Error(
          `Activate did not bring ${target.bundleId} to foreground (state=${appState.label}).`
        );
      }
      if (foreground.verified && foreground.target.bundleId !== target.bundleId) {
        throw new Error(
          `Activate foreground verification failed for ${target.bundleId}; active app is ${foreground.target.bundleId}.`
        );
      }
      setActiveTarget(context, target);
      return {
        result: withTargetMetadata(target, {
          ...appState,
          activeApp: foreground.activeApp,
          targetVerified: foreground.verified
        })
      };
    }
    case "app.terminate": {
      const target = resolveTarget(context, args);
      await driver.execute("mobile: terminateApp", { bundleId: target.bundleId });
      if (getActiveTarget(context).bundleId === target.bundleId) {
        context.activeTarget = undefined;
      }
      return {
        result: withTargetMetadata(
          target,
          await queryAppState(driver, target.bundleId)
        )
      };
    }
    case "app.state": {
      const target = resolveTarget(context, args);
      return {
        result: withTargetMetadata(
          target,
          await queryAppState(driver, target.bundleId)
        )
      };
    }
    case "ui.summary":
      return {
        result: withTargetMetadata(
          (await getForegroundTarget(driver, context)).target,
          await summarizeUi(driver, context, args)
        )
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
        result: listLabels(source, normalizeLimit(args.limit, 40), buildInspectOptions(args))
      };
    }
    case "ui.tree": {
      const source = await driver.getPageSource();
      return {
        result: buildTreeLines(source, normalizeLimit(args.limit, 40), buildInspectOptions(args))
      };
    }
    case "ui.read": {
      const selector = requireArg([args.selector], 0, "ui.read requires args.selector");
      const element = await driver.$(selector);
      return {
        result: {
          selector,
          ...(await readElementState(element, Array.isArray(args.attributes) ? args.attributes : []))
        }
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
    case "ui.focusSearch":
      return {
        result: await focusSearchField(driver, args)
      };
    case "ui.search":
      return {
        result: await searchInUi(driver, args)
      };
    case "ui.wait": {
      const selector = requireArg([args.selector], 0, "ui.wait requires args.selector");
      const timeout = normalizeLimit(args.timeoutMs, 10000);
      const element = await driver.$(selector);
      await element.waitForExist({ timeout });
      return { result: true };
    }
    case "ui.back":
      return {
        result: await navigateBack(driver)
      };
    case "ui.swipe": {
      const direction = normalizeDirection(args.direction, "up");
      await driver.execute("mobile: swipe", { direction });
      return {
        result: direction
      };
    }
    case "ui.scroll": {
      const direction = normalizeDirection(args.direction, "down");
      await driver.execute("mobile: scroll", { direction });
      return {
        result: direction
      };
    }
    default:
      throw new Error(`Unknown command '${command}'.`);
  }
}
