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

// Device-level modals that can never be part of a legitimate smoke flow. They
// are SpringBoard alerts, so they swallow every tap while the Flutter view
// stays in the accessibility tree underneath: elements are still *found* and
// *clicked* successfully, the taps just never reach the app. The suite then
// fails on whatever selector the blocked navigation was waiting for, which
// points at the app instead of the device.
//
// This is not hypothetical: an "Apple Account Sign In Requested" 2FA prompt sat
// on the CI iPhone for four consecutive runs, and all 11 specs failed with
// `element ("~automation.screen_settings") still not existing after 15000ms`.
// Fail fast with the alert text instead.
//
// Deliberately narrow, and biased that way on purpose: a missed pattern just
// falls back to today's behavior (a selector timeout), whereas a false positive
// fails a run that would have passed. So match only alerts that unambiguously
// need a human at the device, and never anything a flow can raise.
//
// In particular this must NOT match on "Apple ID"/"Apple Account" alone: the
// StoreKit sandbox purchase sheet legitimately prompts for Apple ID sign-in
// mid-flow (dep-validate Stage D drives purchase/restore). Only the 2FA
// approval phrasing — "<Apple Account|Apple ID> Sign In Requested" — is matched.
const blockingSystemAlertPatterns = [
  /sign[- ]in requested/i,
  /software update/i,
  /storage is (almost )?full/i,
  /trust this computer/i
];

export class BlockingSystemAlertError extends Error {
  constructor(public readonly alertText: string) {
    super(
      `Unexpected system alert is blocking the device: "${alertText}". ` +
        "It swallows every tap, so the app cannot be driven. Dismiss it on " +
        "the device and re-run."
    );
    this.name = "BlockingSystemAlertError";
  }
}

/** Throws when `text` is a device-level modal only a human at the device can clear. */
function assertNotBlockingSystemAlert(text: string): void {
  if (blockingSystemAlertPatterns.some((pattern) => pattern.test(text))) {
    throw new BlockingSystemAlertError(text);
  }
}

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
      // A device-level modal blocks the whole suite — fail now, with the text.
      assertNotBlockingSystemAlert(alertText);
      // Any other non-notification alert is a flow alert (VPN/DNS profile,
      // StoreKit); leave it for the caller to handle.
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
