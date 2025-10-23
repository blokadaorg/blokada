import { $, $$, driver } from "@wdio/globals";

import { waitForAppForeground } from "./app.js";

export const SETTINGS_BUNDLE_ID = "com.apple.Preferences";

const installButtonPredicates = [
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name CONTAINS[c] 'Allow' OR label CONTAINS[c] 'Allow')",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name CONTAINS[c] 'Install' OR label CONTAINS[c] 'Install')",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name CONTAINS[c] 'Tillåt' OR label CONTAINS[c] 'Tillåt')",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name CONTAINS[c] 'Installera' OR label CONTAINS[c] 'Installera')"
];

const profileCellPredicates = [
  "-ios predicate string: type == 'XCUIElementTypeCell' AND (name CONTAINS[c] 'Blokada' OR label CONTAINS[c] 'Blokada')",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND (name CONTAINS[c] 'DNS' OR label CONTAINS[c] 'DNS')"
];

const dnsSwitchPredicates = [
  "-ios predicate string: type == 'XCUIElementTypeSwitch' AND (name CONTAINS[c] 'Blokada' OR label CONTAINS[c] 'Blokada')",
  "-ios predicate string: type == 'XCUIElementTypeSwitch' AND (name CONTAINS[c] 'DNS' OR label CONTAINS[c] 'DNS')",
  "-ios predicate string: type == 'XCUIElementTypeSwitch'"
];

const devDnsOptionSelectors = [
  "-ios class chain:**/XCUIElementTypeCell[`name == 'Dev' OR label == 'Dev'`]",
  "-ios class chain:**/XCUIElementTypeCell[`name CONTAINS[c] 'Dev' OR label CONTAINS[c] 'Dev'`]"
];

const dnsProfileCellSelectors = [
  "-ios class chain:**/XCUIElementTypeCell[`name CONTAINS[c] 'Blokada' OR label CONTAINS[c] 'Blokada'`]",
  "-ios class chain:**/XCUIElementTypeCell[`name CONTAINS[c] 'Dev' OR label CONTAINS[c] 'Dev'`]",
  "-ios class chain:**/XCUIElementTypeCell[`name CONTAINS[c] 'NextDNS' OR label CONTAINS[c] 'NextDNS'`]"
];

const preferredDnsProfiles = ["Dev", "Blokada", "Blokada Family", "NextDNS"];

const alertDismissSelectors = [
  "~Allow",
  "~Tillåt",
  "~OK",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name CONTAINS[c] 'Allow' OR label CONTAINS[c] 'Allow')",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name CONTAINS[c] 'OK' OR label CONTAINS[c] 'OK')"
];

const rootTitleHints = ["settings", "inställningar", "ustawienia"];
const generalTitleHints = ["general", "allmänt", "ogólne"];
const vpnTitleHints = ["vpn", "enhetshantering", "zarządz"];
const dnsTitleHints = ["dns"];

const backButtonSelectors = [
  "~BackButton",
  "-ios class chain:**/XCUIElementTypeButton[`name == 'Settings' OR label == 'Settings'`]",
  "-ios class chain:**/XCUIElementTypeButton[`name == 'Inställningar' OR label == 'Inställningar'`]",
  "-ios class chain:**/XCUIElementTypeButton[`name == 'Apps' OR label == 'Apps'`]",
  "-ios class chain:**/XCUIElementTypeButton[`name == 'Appar' OR label == 'Appar'`]",
  "-ios class chain:**/XCUIElementTypeNavigationBar/XCUIElementTypeButton[1]"
];

const searchFieldSelectors = [
  "-ios class chain:**/XCUIElementTypeSearchField"
];

const searchCancelSelectors = [
  "~Cancel",
  "~Avbryt",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name == 'Cancel' OR label == 'Cancel')",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name == 'Avbryt' OR label == 'Avbryt')",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name CONTAINS[c] 'Cancel' OR label CONTAINS[c] 'Cancel')",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name CONTAINS[c] 'Avbryt' OR label CONTAINS[c] 'Avbryt')"
];

const searchClearSelectors = [
  "-ios class chain:**/XCUIElementTypeButton[`name == 'Clear text' OR label == 'Clear text'`]",
  "-ios class chain:**/XCUIElementTypeButton[`name == 'Rensa text' OR label == 'Rensa text'`]",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name CONTAINS[c] 'Clear' OR label CONTAINS[c] 'Clear')",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (name CONTAINS[c] 'Rensa' OR label CONTAINS[c] 'Rensa')"
];

const generalSectionSelectors = [
  "-ios predicate string: type == 'XCUIElementTypeCell' AND identifier == 'General'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND (name == 'General' OR label == 'General')",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND (name == 'Allmänt' OR label == 'Allmänt')",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND (name == 'Ogólne' OR label == 'Ogólne')",
  "~General",
  "~Allmänt",
  "~Ogólne"
];

const vpnDeviceManagementSelectors = [
  "-ios predicate string: type == 'XCUIElementTypeCell' AND identifier == 'VPN_DEVICE_MANAGEMENT'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND name == 'VPN & Device Management'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND label == 'VPN & Device Management'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND name == 'VPN och enhetshantering'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND label == 'VPN och enhetshantering'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND name == 'VPN och enhetshantering…'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND label == 'VPN och enhetshantering…'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND name == 'VPN i zarządzanie urządzeniami'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND label == 'VPN i zarządzanie urządzeniami'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND name == 'VPN i zarządzanie urządzeniem'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND label == 'VPN i zarządzanie urządzeniem'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND (name CONTAINS[c] 'VPN' AND (name CONTAINS[c] 'Device' OR name CONTAINS[c] 'enhet' OR name CONTAINS[c] 'zarządz'))",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND (label CONTAINS[c] 'VPN' AND (label CONTAINS[c] 'Device' OR label CONTAINS[c] 'enhet' OR label CONTAINS[c] 'zarządz'))",
  "~VPN & Device Management",
  "~VPN och enhetshantering"
];

const dnsSectionSelectors = [
  "-ios predicate string: type == 'XCUIElementTypeCell' AND identifier == 'DNS'",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND (name == 'DNS' OR label == 'DNS')",
  "-ios predicate string: type == 'XCUIElementTypeCell' AND (name CONTAINS[c] 'DNS' OR label CONTAINS[c] 'DNS')",
  "~DNS"
];

async function tapIfPresent(selector: string): Promise<boolean> {
  try {
    const element = await $(selector);
    if (await element.isExisting()) {
      if (await element.isDisplayed()) {
        await element.click();
        await driver.pause(250);
        return true;
      }
      await element.waitForDisplayed({ timeout: 500 }).catch(() => undefined);
      await element.click();
      await driver.pause(250);
      return true;
    }
  } catch (error) {
    console.warn(`tapIfPresent failed for ${selector}: ${String(error)}`);
  }
  return false;
}

async function tapAny(selectors: string[]): Promise<boolean> {
  for (const selector of selectors) {
    const tapped = await tapIfPresent(selector);
    if (tapped) {
      return true;
    }
  }
  return false;
}

async function swipeUp(): Promise<void> {
  try {
    await driver.execute("mobile: swipe", { direction: "up" });
  } catch (_) {
    try {
      await driver.execute("mobile: scroll", { direction: "down" });
    } catch (error) {
      console.warn(`Unable to swipe in Settings: ${String(error)}`);
    }
  }
}

async function getNavigationTitle(): Promise<string | undefined> {
  try {
    const navBar = await $("-ios class chain:**/XCUIElementTypeNavigationBar[1]");
    if (!(await navBar.isExisting())) {
      return undefined;
    }
    const name = await navBar.getAttribute("name");
    if (typeof name === "string" && name.trim().length > 0) {
      return name;
    }
    const label = await navBar.getAttribute("label");
    if (typeof label === "string" && label.trim().length > 0) {
      return label;
    }
  } catch (_) {
    // Navigation bar not available; ignore.
  }
  return undefined;
}

async function exitSearchModeIfNeeded(): Promise<boolean> {
  try {
    const searchField = await $(searchFieldSelectors[0]);
    if (!(await searchField.isExisting())) {
      return false;
    }

    const value = await searchField.getAttribute("value");
    if (typeof value === "string" && value.trim().length > 0) {
      const cleared = await tapAny(searchClearSelectors);
      if (!cleared) {
        try {
          await searchField.clearValue();
        } catch (clearError) {
          console.warn(`Failed to clear search field directly: ${String(clearError)}`);
        }
      }
      await driver.pause(400);
    }

    const cancelTapped = await tapAny(searchCancelSelectors);
    if (cancelTapped) {
      await driver.pause(800);
      return true;
    }
  } catch (error) {
    console.warn(`exitSearchModeIfNeeded encountered an error: ${String(error)}`);
  }
  return false;
}

async function ensureSettingsRoot(maxAttempts = 12): Promise<void> {
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const title = (await getNavigationTitle())?.toLowerCase() ?? "";
    if (rootTitleHints.some((hint) => title.includes(hint))) {
      return;
    }

    const searchDismissed = await exitSearchModeIfNeeded();
    if (searchDismissed) {
      continue;
    }

    const tapped = await tapAny(backButtonSelectors);
    if (tapped) {
      await driver.pause(800);
      continue;
    }

    await swipeInSettings("right");
    await driver.pause(600);
  }
}

async function swipeInSettings(direction: "up" | "down" | "left" | "right"): Promise<void> {
  try {
    await driver.execute("mobile: swipe", { direction });
  } catch (_) {
    if (direction === "up" || direction === "down") {
      try {
        await driver.execute("mobile: scroll", { direction });
      } catch (error) {
        console.warn(`Unable to swipe ${direction} in Settings: ${String(error)}`);
      }
    } else {
      console.warn(`Unable to swipe ${direction} in Settings: gesture not supported.`);
    }
  }
  await driver.pause(350);
}

async function findElementWithScroll(
  selectors: string[],
  description: string,
  maxScrolls = 8
): Promise<WebdriverIO.Element | undefined> {
  const directions: Array<"up" | "down"> = ["up", "down"];
  for (let scroll = 0; scroll <= maxScrolls; scroll += 1) {
    for (const selector of selectors) {
      try {
        const element = await $(selector);
        if (await element.isExisting()) {
          return element;
        }
      } catch (error) {
        console.warn(`Selector ${selector} check failed while searching for ${description}: ${String(error)}`);
      }
    }

    if (scroll === maxScrolls) {
      break;
    }

    const direction = directions[scroll % directions.length];
    await swipeInSettings(direction);
  }

  console.warn(`Unable to locate ${description} in Settings after scrolling.`);
  return undefined;
}

async function openSettingsSection(
  selectors: string[],
  description: string,
  expectedTitleHints?: string[],
  maxAttempts = 3
): Promise<void> {
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const element = await findElementWithScroll(selectors, description);
    if (!element) {
      break;
    }

    let target = element;
    try {
      let elementType = await element.getAttribute("type");
      let cursor = element;
      const maxDepth = 4;
      for (let depth = 0; depth < maxDepth && elementType !== "XCUIElementTypeCell"; depth += 1) {
        cursor = await cursor.$("..");
        if (!(await cursor.isExisting())) {
          break;
        }
        elementType = await cursor.getAttribute("type");
        if (elementType === "XCUIElementTypeCell") {
          target = cursor;
          break;
        }
      }
    } catch (error) {
      console.warn(`Failed to resolve parent element for ${description}: ${String(error)}`);
    }

    try {
      await target.click();
      await driver.pause(800);
    } catch (error) {
      console.warn(`Click on ${description} failed: ${String(error)}`);
      continue;
    }

    if (!expectedTitleHints || expectedTitleHints.length === 0) {
      return;
    }

    const title = (await getNavigationTitle())?.toLowerCase() ?? "";
    if (expectedTitleHints.some((hint) => title.includes(hint))) {
      return;
    }

    console.warn(
      `After selecting ${description}, navigation title '${title}' did not match expected hints; backing out and retrying.`
    );
    await tapAny(backButtonSelectors);
    await driver.pause(800);
  }

  throw new Error(`Failed to find ${description} in Settings.`);
}

async function openProfileDetails(): Promise<boolean> {
  for (const selector of profileCellPredicates) {
    const cells = await $$(selector);
    for (const cell of cells) {
      if (await cell.isExisting()) {
        await cell.click();
        await driver.pause(500);
        return true;
      }
    }
  }
  return false;
}

async function toggleDnsSwitchIfNeeded(): Promise<boolean> {
  for (const selector of dnsSwitchPredicates) {
    const switches = await $$(selector);
    for (const control of switches) {
      const value = await control.getAttribute("value");
      if (typeof value === "string" && value === "1") {
        return true;
      }
      if (typeof value === "string" && value === "0") {
        await control.click();
        await driver.pause(500);
        const updated = await control.getAttribute("value");
        if (typeof updated === "string" && updated === "1") {
          return true;
        }
      }
    }
  }
  return false;
}

async function tapDevDnsOptionIfPresent(): Promise<boolean> {
  const option = await findElementWithScroll(devDnsOptionSelectors, "Dev DNS option", 2);
  if (!option) {
    return false;
  }

  try {
    await option.click();
    await driver.pause(300);
    return true;
  } catch (error) {
    console.warn(`Failed to tap Dev DNS option: ${String(error)}`);
    return false;
  }
}

async function dismissAnyAlerts(): Promise<void> {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const dismissed = await tapAny(alertDismissSelectors);
    if (!dismissed) {
      break;
    }
  }
}

export async function waitForSettingsForeground(timeout = 20000): Promise<void> {
  try {
    await waitForAppForeground(SETTINGS_BUNDLE_ID, timeout);
  } catch (error) {
    console.warn(`Settings did not reach foreground automatically: ${String(error)}. Forcing activation.`);
    await driver.execute("mobile: launchApp", { bundleId: SETTINGS_BUNDLE_ID });
    await waitForAppForeground(SETTINGS_BUNDLE_ID, timeout);
  }
}

export async function enableDnsProfile(): Promise<void> {
  await dismissAnyAlerts();

  // Ensure we start from the root of Settings before navigating.
  await ensureSettingsRoot();

  const title = (await getNavigationTitle())?.toLowerCase() ?? "";
  if (!rootTitleHints.some((hint) => title.includes(hint))) {
    await ensureSettingsRoot();
  }

  await openSettingsSection(generalSectionSelectors, "General / Allmänt", generalTitleHints);
  await openSettingsSection(vpnDeviceManagementSelectors, "VPN & Device Management", vpnTitleHints);
  await dismissAnyAlerts();
  await openSettingsSection(dnsSectionSelectors, "DNS", dnsTitleHints);
  await dismissAnyAlerts();

  const devTapped = await tapDevDnsOptionIfPresent();
  if (devTapped) {
    await dismissAnyAlerts();
    return;
  }

  const tappedInstall = await tapAny(installButtonPredicates);
  if (tappedInstall) {
    await dismissAnyAlerts();
  }

  let profileOpened = await openProfileDetails();
  if (!profileOpened) {
    // Scroll and retry to surface the profile entry.
    for (let attempt = 0; attempt < 3 && !profileOpened; attempt += 1) {
      await swipeInSettings("up");
      profileOpened = await openProfileDetails();
    }
  }

  if (!profileOpened) {
    throw new Error("Unable to open Blokada DNS profile details.");
  }

  for (let attempt = 0; attempt < 3; attempt += 1) {
    const installTapped = await tapAny(installButtonPredicates);
    if (installTapped) {
      await dismissAnyAlerts();
    }

    const toggled = await toggleDnsSwitchIfNeeded();
    if (toggled) {
      await dismissAnyAlerts();
      return;
    }
    await swipeInSettings("up");
  }

  throw new Error("Failed to enable DNS profile within Settings.");
}
