import { $, driver } from "@wdio/globals";

import { AutomationIds } from "../support/automationIds.js";

const dnsSheetSelector = `~${AutomationIds.dnsOnboardingSheet}`;
const dnsOpenSettingsSelector = `~${AutomationIds.dnsOpenSettings}`;
const introOverlaySelector = `~${AutomationIds.onboardIntroSheet}`;
const introContinueSelector = `~${AutomationIds.onboardContinue}`;

const introContinueCandidates = [
  introContinueSelector,
  "~Fortsätt",
  "~Continue",
  "~Fortsette",
  "~Fortsetzen",
  "-ios predicate string: label CONTAINS[c] 'Fortsätt' OR label CONTAINS[c] 'Continue'"
];

const legacyOpenSettingsSelectors = [
  "~dnsprofile action open settings",
  "~Open Settings",
  "~Öppna Inställningar",
  "-ios predicate string: label CONTAINS[c] 'Open Settings'",
  "-ios predicate string: label CONTAINS[c] 'Inställningar'"
];

export async function waitForDnsOnboardingSheet(timeout = 20000): Promise<void> {
  const sheet = await $(dnsSheetSelector);
  await sheet.waitForExist({ timeout });
}

export async function waitForDnsOnboardingDismiss(timeout = 10000): Promise<void> {
  try {
    const sheet = await $(dnsSheetSelector);
    await sheet.waitForExist({ timeout, reverse: true });
  } catch (error) {
    console.warn(`DNS onboarding sheet dismissal wait failed: ${String(error)}`);
  }
}

export async function dismissIntroOverlayIfPresent(timeout = 8000): Promise<void> {
  const overlay = await $(introOverlaySelector);
  const exists = await overlay.waitForExist({ timeout }).catch(() => false);
  if (!exists) {
    return;
  }

  for (const candidate of introContinueCandidates) {
    try {
      const button = await $(candidate);
      await button.waitForExist({ timeout: 4000 });
      await button.click();
      await driver.pause(1000);
      return;
    } catch (error) {
      console.warn(`Intro continue selector ${candidate} failed: ${String(error)}`);
    }
  }
}

export async function openDnsSettingsFromSheet(timeout = 15000): Promise<void> {
  const semanticButton = await $(dnsOpenSettingsSelector);
  if (await semanticButton.isExisting()) {
    await semanticButton.click();
    return;
  }

  for (const selector of legacyOpenSettingsSelectors) {
    const element = await $(selector);
    if (await element.isExisting()) {
      await element.click();
      return;
    }
  }

  // Fall back to tapping the lower portion of the sheet if specific buttons were not resolved.
  try {
    const sheet = await $(dnsSheetSelector);
    if (await sheet.isExisting()) {
      const location = await sheet.getLocation();
      const size = await sheet.getSize();
      const tapX = Math.round(location.x + size.width / 2);
      const tapY = Math.round(location.y + size.height - size.height * 0.15);
      await driver.execute("mobile: tap", { x: tapX, y: tapY });
      await driver.pause(1000);
      return;
    }
  } catch (error) {
    console.warn(`Fallback tap on DNS sheet failed: ${String(error)}`);
  }

  throw new Error("Failed to locate 'Open Settings' action on the DNS onboarding sheet.");
}
