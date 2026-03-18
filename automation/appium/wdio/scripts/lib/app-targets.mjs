export const SIX_BUNDLE_ID = "net.blocka.app";
export const FAMILY_BUNDLE_ID = "net.blocka.app.family";
export const SETTINGS_BUNDLE_ID = "com.apple.Preferences";

const KNOWN_APP_TARGETS = {
  six: {
    bundleId: SIX_BUNDLE_ID,
    displayName: "Blokada 6",
    aliases: ["six", "blokada6", "blokada-6"]
  },
  family: {
    bundleId: FAMILY_BUNDLE_ID,
    displayName: "Blokada Family",
    aliases: ["family", "blokada-family"]
  }
};

function normalizeFlavor(value) {
  const normalized = String(value ?? "")
    .trim()
    .toLowerCase();
  if (normalized === "family") {
    return "family";
  }
  if (["6", "six", "blokada", "blokada6", "blokada-6"].includes(normalized)) {
    return "six";
  }
  return undefined;
}

function readExplicitFlavor(env = process.env) {
  const rawFlavor = String(env.APP_FLAVOR ?? "").trim();
  if (!rawFlavor) {
    return undefined;
  }

  const explicitFlavor = normalizeFlavor(rawFlavor);
  if (!explicitFlavor) {
    throw new Error(
      `Unsupported APP_FLAVOR='${rawFlavor}'. Expected one of: six, 6, blokada, blokada6, blokada-6, family.`
    );
  }

  return explicitFlavor;
}

function getKnownTargetEntries() {
  return Object.entries(KNOWN_APP_TARGETS).map(([name, target]) => ({
    name,
    ...target
  }));
}

export function resolveAppFlavor(env = process.env) {
  const explicitFlavor = readExplicitFlavor(env);
  if (explicitFlavor) {
    return explicitFlavor;
  }

  const configuredBundleId = String(env.APP_BUNDLE_ID ?? "").trim();
  if (configuredBundleId === FAMILY_BUNDLE_ID) {
    return "family";
  }

  return "six";
}

export function resolvePrimaryBundleId(env = process.env) {
  const configuredBundleId = String(env.APP_BUNDLE_ID ?? "").trim();
  if (configuredBundleId) {
    return configuredBundleId;
  }

  return KNOWN_APP_TARGETS[resolveAppFlavor(env)].bundleId;
}

export function resolveAppDisplayName(env = process.env) {
  const configuredDisplayName = String(
    env.APP_DISPLAY_NAME ?? env.APP_NAME ?? ""
  ).trim();
  if (configuredDisplayName) {
    return configuredDisplayName;
  }

  return KNOWN_APP_TARGETS[resolveAppFlavor(env)].displayName;
}

export function resolveInstallTarget(env = process.env) {
  return resolveAppFlavor(env) === "family"
    ? "appium-install-family"
    : "appium-install-six";
}

export function buildKnownAppTargets() {
  const targets = getKnownTargetEntries().map((target) => ({
    name: target.name,
    aliases: [...target.aliases],
    bundleId: target.bundleId
  }));

  targets.push({
    name: "settings",
    aliases: ["settings"],
    bundleId: SETTINGS_BUNDLE_ID
  });

  return targets;
}
