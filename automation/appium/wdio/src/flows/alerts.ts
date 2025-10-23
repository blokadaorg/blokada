import { driver } from "@wdio/globals";

const notificationButtonLabels = [
  "Allow",
  "Allow While Using App",
  "Allow Once",
  "Tillåt",
  "Tillåt medan appen används",
  "Tillåt en gång",
  "OK",
  "Дозволити",
  "Разрешить",
  "Permitir"
];

const notificationButtonSelectors = [
  ...notificationButtonLabels.map((label) => `~${label}`),
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (label CONTAINS[c] 'Allow' OR name CONTAINS[c] 'Allow')",
  "-ios predicate string: type == 'XCUIElementTypeButton' AND (label CONTAINS[c] 'Tillåt' OR name CONTAINS[c] 'Tillåt')",
  "-ios class chain:**/XCUIElementTypeButton[`label CONTAINS[c] 'Allow'`]",
  "-ios class chain:**/XCUIElementTypeButton[`label CONTAINS[c] 'Tillåt'`]"
];

function looksLikeNotification(text: string | undefined): boolean {
  if (!text) {
    return false;
  }
  const normalized = text.toLowerCase();
  return (
    normalized.includes("notification") ||
    normalized.includes("avisering") ||
    normalized.includes("notif") ||
    normalized.includes("notificación") ||
    normalized.includes("notiser")
  );
}

export async function acceptNotificationAlert(timeout = 5000): Promise<void> {
  const end = Date.now() + timeout;
  let alertText: string | undefined;

  while (Date.now() < end) {
    try {
      alertText = await driver.getAlertText();
      break;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (message.toLowerCase().includes("modal dialog when one was not open")) {
        return;
      }
      await driver.pause(200);
    }
  }

  if (!alertText) {
    return;
  }

  if (!looksLikeNotification(alertText)) {
    return;
  }

  for (const label of notificationButtonLabels) {
    try {
      await driver.execute("mobile: alert", {
        action: "accept",
        buttonLabel: label
      });
      await driver.pause(500);
      return;
    } catch (error) {
      // Some driver versions do not support this extension; ignore.
      console.warn(`Notification alert accept failed for label '${label}': ${String(error)}`);
    }
  }

  for (const selector of notificationButtonSelectors) {
    try {
      const element = await driver.$(selector);
      if (await element.isExisting()) {
        await element.click();
        await driver.pause(500);
        return;
      }
    } catch (error) {
      console.warn(`Notification selector '${selector}' failed: ${String(error)}`);
    }
  }

  try {
    await driver.acceptAlert();
    await driver.pause(500);
  } catch (error) {
    console.warn(`Notification alert accept fallback failed: ${String(error)}`);
  }
}
