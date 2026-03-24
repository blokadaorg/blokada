import { createWriteStream, existsSync } from "node:fs";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { spawn, spawnSync } from "node:child_process";

import { getAppiumServerConfig, getProjectPaths } from "./paths.mjs";

const WDA_KEYBOARD_PATCH_MARKER =
  "Blokada: preserve current iOS keyboard preferences during Appium sessions.";
const WDA_KEYBOARD_PREFERENCES_TARGET =
  "  [FBConfiguration configureDefaultKeyboardPreferences];";

export function parseBooleanFlag(value, fallback = false) {
  if (value == null || value === "") {
    return fallback;
  }

  const normalized = String(value).trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) {
    return true;
  }
  if (["0", "false", "no", "off"].includes(normalized)) {
    return false;
  }

  return fallback;
}

export function parseInstalledDrivers(rawOutput) {
  const payload = JSON.parse(rawOutput);
  return Object.entries(payload).filter(([, value]) => value?.installed === true);
}

export function hasInstalledDriver(rawOutput, driverName = "xcuitest") {
  return parseInstalledDrivers(rawOutput).some(([name]) => name === driverName);
}

function getRuntimeEnv(env = process.env) {
  const paths = getProjectPaths(env);
  return {
    ...env,
    APPIUM_HOME: paths.appiumHome
  };
}

function runAppiumCli(args, env = process.env) {
  const paths = getProjectPaths(env);
  return spawnSync(paths.appiumBinary, args, {
    encoding: "utf8",
    env: getRuntimeEnv(env)
  });
}

function runDevicectl(args, env = process.env) {
  return spawnSync("xcrun", ["devicectl", ...args], {
    encoding: "utf8",
    env
  });
}

function getWdaKeyboardPreferencesFilePath(env = process.env) {
  const paths = getProjectPaths(env);
  return resolve(
    paths.appiumHome,
    "node_modules",
    "appium-xcuitest-driver",
    "node_modules",
    "appium-webdriveragent",
    "WebDriverAgentRunner",
    "UITestingUITests.m"
  );
}

async function readWdaKeyboardPatchAsset(env = process.env) {
  const paths = getProjectPaths(env);

  if (!existsSync(paths.wdaKeyboardPatchPath)) {
    throw new Error(
      `Expected WebDriverAgent patch asset at ${paths.wdaKeyboardPatchPath}, but it was not found.`
    );
  }

  return readFile(paths.wdaKeyboardPatchPath, "utf8");
}

export function patchWdaKeyboardPreferencesSource(source, replacement) {
  if (source.includes(WDA_KEYBOARD_PATCH_MARKER)) {
    return source;
  }

  if (!replacement?.includes(WDA_KEYBOARD_PATCH_MARKER)) {
    throw new Error("WebDriverAgent keyboard patch asset is missing the expected marker.");
  }

  if (!source.includes(WDA_KEYBOARD_PREFERENCES_TARGET)) {
    throw new Error("WebDriverAgent keyboard preferences hook not found.");
  }

  return source.replace(WDA_KEYBOARD_PREFERENCES_TARGET, replacement.trimEnd());
}

export async function ensurePatchedWebDriverAgent(options = {}) {
  const {
    env = process.env,
    log = console.error
  } = options;

  const sourcePath = getWdaKeyboardPreferencesFilePath(env);
  if (!existsSync(sourcePath)) {
    throw new Error(
      `Expected WebDriverAgent source at ${sourcePath}, but it was not found.`
    );
  }

  const currentSource = await readFile(sourcePath, "utf8");
  const patchAsset = await readWdaKeyboardPatchAsset(env);
  const patchedSource = patchWdaKeyboardPreferencesSource(currentSource, patchAsset);
  if (patchedSource === currentSource) {
    return false;
  }

  await writeFile(sourcePath, patchedSource);
  log("Patched repo-local WebDriverAgent to preserve iOS keyboard preferences.");
  return true;
}

export function parseRunningProcesses(rawOutput) {
  const payload = JSON.parse(rawOutput);
  return payload?.result?.runningProcesses ?? [];
}

function getProcessNameCandidates(processInfo) {
  const executable = processInfo?.executable;
  const executableName =
    typeof executable === "string"
      ? executable
      : executable?.name;

  return [
    processInfo?.name,
    executableName
  ]
    .filter((value) => typeof value === "string")
    .map((value) => String(value));
}

export function findWebDriverAgentProcessIds(rawOutput) {
  return parseRunningProcesses(rawOutput)
    .filter((processInfo) => {
      const candidates = getProcessNameCandidates(processInfo);
      return candidates.some((name) => String(name).includes("WebDriverAgent"));
    })
    .map((processInfo) =>
      processInfo?.processIdentifier ??
      processInfo?.pid ??
      processInfo?.ProcessIdentifier
    )
    .filter((value) => Number.isInteger(value));
}

export function findAutomationModeProcessIds(rawOutput) {
  return parseRunningProcesses(rawOutput)
    .filter((processInfo) => {
      const candidates = getProcessNameCandidates(processInfo);
      return candidates.some((name) =>
        String(name).includes("AutomationMode")
      );
    })
    .map((processInfo) =>
      processInfo?.processIdentifier ??
      processInfo?.pid ??
      processInfo?.ProcessIdentifier
    )
    .filter((value) => Number.isInteger(value));
}

export function hasRunningWebDriverAgent(rawOutput) {
  return findWebDriverAgentProcessIds(rawOutput).length > 0;
}

async function terminateDeviceProcesses(processIds, options = {}) {
  const {
    deviceIdentifier,
    env = process.env,
    log = console.error,
    processLabel = "device"
  } = options;

  if (!deviceIdentifier || processIds.length === 0) {
    return false;
  }

  for (const processId of processIds) {
    const terminateResult = runDevicectl(
      [
        "device",
        "process",
        "terminate",
        "--device",
        deviceIdentifier,
        "--pid",
        String(processId),
        "--kill"
      ],
      env
    );

    if (terminateResult.status !== 0) {
      log(
        terminateResult.stderr ||
        terminateResult.stdout ||
        `Failed to terminate ${processLabel} process ${processId}.`
      );
    }
  }

  return true;
}

export function isHardResetRequested(env = process.env) {
  return parseBooleanFlag(env.APPIUM_WDA_HARD_RESET, false);
}

export function selectAutomationReuseStrategy({
  appiumServerReady,
  hardResetRequested,
  runningWebDriverAgent
}) {
  if (hardResetRequested) {
    return "hard-reset";
  }
  if (appiumServerReady) {
    return "reuse-appium-server";
  }
  if (runningWebDriverAgent) {
    return "reuse-webdriveragent";
  }
  return "fresh-start";
}

async function inspectRunningProcesses(options = {}) {
  const {
    deviceIdentifier,
    env = process.env,
    log = console.error
  } = options;

  if (!deviceIdentifier) {
    return null;
  }

  const tempDir = await mkdtemp(join(tmpdir(), "appium-procs-"));
  const jsonPath = join(tempDir, "processes.json");

  try {
    const listResult = runDevicectl(
      [
        "device",
        "info",
        "processes",
        "--device",
        deviceIdentifier,
        "--json-output",
        jsonPath
      ],
      env
    );

    if (listResult.status !== 0) {
      log(
        listResult.stderr ||
        listResult.stdout ||
        "Failed to inspect device processes for Appium runtime."
      );
      return null;
    }

    return await readFile(jsonPath, "utf8");
  } finally {
    await rm(tempDir, { recursive: true, force: true });
  }
}

export async function ensureAppiumRuntime(options = {}) {
  const {
    env = process.env,
    installDriver = true,
    log = console.error
  } = options;
  const paths = getProjectPaths(env);

  if (!existsSync(paths.appiumBinary)) {
    throw new Error(
      `Local Appium CLI not found at ${paths.appiumBinary}. Run 'npm install' in automation/appium/wdio first.`
    );
  }

  await mkdir(paths.appiumHome, { recursive: true });

  const listResult = runAppiumCli(["driver", "list", "--installed", "--json"], env);
  if (listResult.status !== 0) {
    throw new Error(listResult.stderr || listResult.stdout || "Failed to query installed Appium drivers.");
  }

  if (hasInstalledDriver(listResult.stdout)) {
    await ensurePatchedWebDriverAgent({ env, log });
    return {
      appiumBinary: paths.appiumBinary,
      appiumHome: paths.appiumHome
    };
  }

  if (!installDriver) {
    throw new Error("Appium xcuitest driver is not installed.");
  }

  log("Installing Appium xcuitest driver into the repo-local Appium home...");
  const installResult = runAppiumCli(["driver", "install", "xcuitest"], env);
  if (installResult.status !== 0) {
    throw new Error(
      installResult.stderr || installResult.stdout || "Failed to install Appium xcuitest driver."
    );
  }

  await ensurePatchedWebDriverAgent({ env, log });

  return {
    appiumBinary: paths.appiumBinary,
    appiumHome: paths.appiumHome
  };
}

export async function isAppiumServerReady(env = process.env) {
  const { host, port, path } = getAppiumServerConfig(env);
  const statusPath = path.endsWith("/") ? `${path}status` : `${path}/status`;

  try {
    const response = await fetch(`http://${host}:${port}${statusPath}`);
    if (!response.ok) {
      return false;
    }

    const payload = await response.json();
    return payload?.value?.ready === true || payload?.value?.build != null;
  } catch (_) {
    return false;
  }
}

export async function waitForAppiumServer(env = process.env, timeoutMs = 15000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await isAppiumServerReady(env)) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }

  const { host, port } = getAppiumServerConfig(env);
  throw new Error(`Appium server at ${host}:${port} did not become ready within ${timeoutMs}ms.`);
}

export async function terminateWebDriverAgent(options = {}) {
  const {
    deviceIdentifier,
    env = process.env,
    log = console.error
  } = options;

  if (!deviceIdentifier) {
    return false;
  }

  const processJson = await inspectRunningProcesses({
    deviceIdentifier,
    env,
    log
  });
  if (!processJson) {
    return false;
  }

  const processIds = [
    ...findWebDriverAgentProcessIds(processJson),
    ...findAutomationModeProcessIds(processJson)
  ];

  return terminateDeviceProcesses(processIds, {
    deviceIdentifier,
    env,
    log,
    processLabel: "WebDriverAgent"
  });
}

export async function terminateWebDriverAgentRunner(options = {}) {
  const {
    deviceIdentifier,
    env = process.env,
    log = console.error
  } = options;

  if (!deviceIdentifier) {
    return false;
  }

  const processJson = await inspectRunningProcesses({
    deviceIdentifier,
    env,
    log
  });
  if (!processJson) {
    return false;
  }

  const processIds = findWebDriverAgentProcessIds(processJson);
  return terminateDeviceProcesses(processIds, {
    deviceIdentifier,
    env,
    log,
    processLabel: "WebDriverAgentRunner"
  });
}

export async function ensureLocalAppiumServer(options = {}) {
  const {
    env = process.env,
    log = console.error
  } = options;
  const paths = getProjectPaths(env);

  await ensureAppiumRuntime({ env, log });
  if (await isAppiumServerReady(env)) {
    return {
      started: false,
      stop: async () => {}
    };
  }

  await mkdir(paths.outputDir, { recursive: true });
  const logFile = `${paths.outputDir}/appium-explore-server.log`;
  const output = createWriteStream(logFile, { flags: "a" });
  const child = spawn(paths.appiumBinary, ["--config", paths.appiumConfigPath], {
    env: getRuntimeEnv(env),
    stdio: ["ignore", "pipe", "pipe"]
  });

  child.stdout.pipe(output);
  child.stderr.pipe(output);

  try {
    await waitForAppiumServer(env);
  } catch (error) {
    child.kill("SIGTERM");
    throw error;
  }

  log(`Started local Appium server; logs: ${logFile}`);

  return {
    started: true,
    logFile,
    stop: async () => {
      if (child.exitCode == null && !child.killed) {
        child.kill("SIGTERM");
        await new Promise((resolve) => {
          const forceKill = setTimeout(() => {
            child.kill("SIGKILL");
          }, 2000);

          child.once("exit", () => {
            clearTimeout(forceKill);
            resolve();
          });
        });
      }
      output.end();
    }
  };
}

export async function createManagedAppiumRuntime(options = {}) {
  const {
    deviceIdentifier,
    env = process.env,
    log = console.error
  } = options;

  await ensureAppiumRuntime({ env, log });

  const appiumServerReady = await isAppiumServerReady(env);
  const processJson = await inspectRunningProcesses({
    deviceIdentifier,
    env,
    log
  });
  const runningWebDriverAgent = processJson ? hasRunningWebDriverAgent(processJson) : false;
  const hardResetRequested = isHardResetRequested(env);
  const strategy = selectAutomationReuseStrategy({
    appiumServerReady,
    hardResetRequested,
    runningWebDriverAgent
  });

  if (strategy === "hard-reset") {
    log("Hard reset requested; terminating existing WebDriverAgent before startup.");
    await terminateWebDriverAgent({
      deviceIdentifier,
      env,
      log
    });
  } else if (strategy === "reuse-appium-server") {
    log("Reusing existing local Appium server.");
  } else if (strategy === "reuse-webdriveragent") {
    log("Reusing existing WebDriverAgent on the device.");
  }

  const server = await ensureLocalAppiumServer({ env, log });

  return {
    strategy,
    async softCleanup(options = {}) {
      const { deleteSession } = options;
      await deleteSession?.().catch(() => undefined);
      await terminateWebDriverAgentRunner({
        deviceIdentifier,
        env,
        log
      }).catch(() => undefined);
      await server.stop().catch(() => undefined);
    },
    async hardReset(options = {}) {
      const { deleteSession } = options;
      await deleteSession?.().catch(() => undefined);
      await terminateWebDriverAgent({
        deviceIdentifier,
        env,
        log
      }).catch(() => undefined);
      await server.stop().catch(() => undefined);
    }
  };
}
