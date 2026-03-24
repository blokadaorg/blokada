import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const moduleDir = dirname(fileURLToPath(import.meta.url));
const wdioRoot = resolve(moduleDir, "..", "..");
const appiumRoot = resolve(wdioRoot, "..");
const repoRoot = resolve(wdioRoot, "..", "..", "..");

export function getProjectPaths(env = process.env) {
  return {
    repoRoot,
    appiumRoot,
    wdioRoot,
    assetsRoot: resolve(appiumRoot, "assets"),
    outputDir: resolve(appiumRoot, "output"),
    appiumHome: env.APPIUM_HOME ?? resolve(appiumRoot, ".appium"),
    appiumBinary: resolve(wdioRoot, "node_modules", ".bin", "appium"),
    appiumConfigPath: resolve(repoRoot, ".appiumrc.yaml"),
    wdaKeyboardPatchPath: resolve(
      appiumRoot,
      "assets",
      "wda-preserve-keyboard-preferences.m"
    ),
    signingConfigPath:
      env.IOS_XCODE_CONFIG_FILE ??
      resolve(repoRoot, "ios", "App", "Config", "AppiumSigning.xcconfig")
  };
}

export function getAppiumServerConfig(env = process.env) {
  const rawPort = Number.parseInt(env.APPIUM_PORT ?? "4723", 10);
  const port = Number.isFinite(rawPort) ? rawPort : 4723;

  return {
    host: env.APPIUM_HOST ?? "127.0.0.1",
    port,
    path: env.APPIUM_PATH ?? "/"
  };
}
