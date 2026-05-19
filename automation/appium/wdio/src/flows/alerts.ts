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

export async function acceptNotificationAlert(timeout = 8000): Promise<void> {
  const end = Date.now() + timeout;

  while (Date.now() < end) {
    // getAlertText() does NOT expose iOS SpringBoard system permission
    // prompts — it throws "no modal dialog open" even while the prompt is
    // visible. So it is used only to (a) bail on a *different*
    // (non-notification) app alert we must not auto-accept, and (b) take
    // the locale-aware path when WDA does expose it. Dismissal is then
    // attempted via every mechanism regardless, because the SpringBoard
    // prompt is reachable as a tappable element / via the alert handler
    // even though getAlertText() cannot see it (the previous code returned
    // before ever reaching those paths — the root of the smoke flakiness).
    let alertText: string | undefined;
    try {
      alertText = await driver.getAlertText();
    } catch {
      // SpringBoard alert, or none yet — fall through to the taps below.
    }

    if (alertText && !looksLikeNotification(alertText)) {
      // A non-notification alert is up; leave it for the caller to handle.
      return;
    }

    for (const label of notificationButtonLabels) {
      try {
        await driver.execute("mobile: alert", { action: "accept", buttonLabel: label });
        await driver.pause(500);
        return;
      } catch {
        // Label not present / extension unsupported — try the next.
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
      } catch {
        // Selector unsupported / not present — try the next.
      }
    }

    try {
      await driver.acceptAlert();
      await driver.pause(500);
      return;
    } catch {
      // No accept-able alert this iteration.
    }

    await driver.pause(250);
  }
}
