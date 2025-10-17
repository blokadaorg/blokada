import { $, driver } from "@wdio/globals";

import { AutomationIds } from "../support/automationIds.js";
import { dismissRatePromptIfPresent } from "./modals.js";

const powerToggleSelector = `~${AutomationIds.powerToggle}`;

const fallbackPowerSelectors = [
  "~power-toggle",
  "-ios predicate string: (name CONTAINS[c] 'power' OR label CONTAINS[c] 'power') AND (type == 'XCUIElementTypeButton' OR type == 'XCUIElementTypeOther')",
  "-ios class chain:**/XCUIElementTypeButton[`name CONTAINS[c] 'Power' OR label CONTAINS[c] 'Power'`]",
  "-ios class chain:**/XCUIElementTypeOther[`name CONTAINS[c] 'Power' OR label CONTAINS[c] 'Power'`]"
];

async function locateElement(selector: string) {
  const element = await $(selector);
  return (await element.isExisting()) ? element : undefined;
}

export async function waitForPowerButton(timeout = 20000): Promise<void> {
  const semanticElement = await $(powerToggleSelector);
  try {
    await semanticElement.waitForExist({ timeout });
  } catch (error) {
    await dismissRatePromptIfPresent(2000);
    await semanticElement.waitForExist({ timeout: 5000 });
  }
}

export async function tapPowerButton(): Promise<void> {
  const semanticButton = await locateElement(powerToggleSelector);
  if (semanticButton) {
    await semanticButton.click();
    return;
  }

  for (const selector of fallbackPowerSelectors) {
    try {
      const element = await locateElement(selector);
      if (element) {
        await element.click();
        return;
      }
    } catch (error) {
      console.warn(`Fallback power selector ${selector} failed: ${String(error)}`);
    }
  }

  throw new Error("Failed to locate power toggle via any selector.");
}

export async function waitForProtectionInactive(timeout = 20000): Promise<void> {
  await driver.waitUntil(
    async () => {
      const element = await locateElement(powerToggleSelector);
      if (!element) {
        return false;
      }
      const value = await element.getAttribute("value");
      return typeof value === "string" && value.toLowerCase() === "inactive";
    },
    { timeout, timeoutMsg: "Power toggle did not report inactive state in time" }
  );
}

export async function waitForProtectionActive(timeout = 20000): Promise<void> {
  await driver.waitUntil(
    async () => {
      const element = await locateElement(powerToggleSelector);
      if (!element) {
        return false;
      }
      const value = await element.getAttribute("value");
      return typeof value === "string" && value.toLowerCase() === "active";
    },
    { timeout, timeoutMsg: "Power toggle did not report active state in time" }
  );
}

export async function getProtectionState(): Promise<string | undefined> {
  const element = await locateElement(powerToggleSelector);
  if (!element) {
    return undefined;
  }
  const value = await element.getAttribute("value");
  return typeof value === "string" ? value.toLowerCase() : undefined;
}
