import { $, $$, driver } from "@wdio/globals";

/**
 * Platform layer for the shared smoke flows. iOS keeps its original selectors
 * and commands (`~id`, `element.click()`, XCUITest `mobile:` commands); Android
 * (UiAutomator2 against the Flutter view) needs different ones:
 *
 * - Flutter `Semantics(identifier:)` surfaces as `resource-id` on Android, while
 *   `~` means content-desc there, so ids go through a UiSelector.
 * - Semantics `value` has no attribute of its own on Android: Flutter puts it
 *   first in content-desc ("<value>, <label>, <hint>").
 * - Switch state is the `checked` attribute, not `value`.
 * - `element.click()` does not always fire Flutter buttons (the Private DNS
 *   sheet's "Open Settings" ignored it), so Android taps the element's center.
 * - Flutter only exposes on-screen nodes on Android, so rows below the fold must
 *   be scrolled into view before they can be found.
 */
export function isAndroid(): boolean {
  return Boolean(driver.isAndroid);
}

function uiSelectorString(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

// Character classes instead of backslash escapes: UiSelector strings take no
// escapes inside resourceIdMatches, so `\\.` would not reach the regex intact.
function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|]/g, "[$&]");
}

/** Selector for an automation id (Flutter `Semantics(identifier:)`). */
export function byId(id: string): string {
  if (!isAndroid()) {
    return `~${id}`;
  }
  return `android=new UiSelector().resourceId("${uiSelectorString(id)}")`;
}

/** Selector for the first element whose automation id starts with `prefix`. */
export function byIdPrefix(prefix: string): string {
  if (!isAndroid()) {
    return `-ios predicate string: name BEGINSWITH '${prefix}'`;
  }
  const pattern = uiSelectorString(`^${escapeRegex(prefix)}.*`);
  return `android=new UiSelector().resourceIdMatches("${pattern}")`;
}

/** Drop selectors that only parse on the other platform. */
export function forPlatform(selectors: string[]): string[] {
  if (!isAndroid()) {
    return selectors;
  }
  return selectors.filter((selector) => !selector.startsWith("-ios "));
}

/** The automation id an element exposes. */
export async function automationIdOf(element: WebdriverIO.Element): Promise<string | undefined> {
  const value = await element.getAttribute(isAndroid() ? "resource-id" : "name");
  return typeof value === "string" ? value : undefined;
}

/** The Flutter Semantics `value` of an element. */
export async function semanticValueOf(
  element: WebdriverIO.Element
): Promise<string | undefined> {
  if (!isAndroid()) {
    const value = await element.getAttribute("value");
    return typeof value === "string" ? value : undefined;
  }
  const description = await element.getAttribute("content-desc");
  if (typeof description !== "string" || description.length === 0) {
    return undefined;
  }
  return description.split(", ")[0];
}

/** On/off state of a switch: iOS "1"/"0" value, Android "true"/"false" checked. */
export async function switchStateOf(element: WebdriverIO.Element): Promise<string | undefined> {
  const value = await element.getAttribute(isAndroid() ? "checked" : "value");
  return typeof value === "string" ? value : undefined;
}

/**
 * Android only: let a route transition finish. Without XCUITest's implicit
 * waits, the next tap can start a push while a pop is still animating, which
 * leaves the top-bar title stuck invisible (opacity 0, so absent from the tree).
 */
export async function settleNavigation(): Promise<void> {
  if (isAndroid()) {
    await driver.pause(800);
  }
}

/** Tap a screen point. */
export async function tapAt(x: number, y: number): Promise<void> {
  if (!isAndroid()) {
    await driver.execute("mobile: tap", { x, y });
    return;
  }
  await driver.execute("mobile: clickGesture", { x: Math.round(x), y: Math.round(y) });
}

/** Tap an element: `click()` on iOS, a tap at its center on Android. */
export async function tap(element: WebdriverIO.Element): Promise<void> {
  if (!isAndroid()) {
    await element.click();
    return;
  }
  const rect = await settledRect(element);
  await tapAt(rect.x + rect.width / 2, rect.y + rect.height / 2);
}

type Rect = { x: number; y: number; width: number; height: number };

/**
 * The element's bounds once they stop moving. A coordinate tap reads them at
 * one instant, and during a route transition Flutter slides the whole screen,
 * so a tap computed mid-animation lands beside the target.
 */
async function settledRect(element: WebdriverIO.Element, timeout = 3000): Promise<Rect> {
  const end = Date.now() + timeout;
  let previous = await driver.getElementRect(await element.elementId);
  while (Date.now() < end) {
    await driver.pause(150);
    const current = await driver.getElementRect(await element.elementId);
    if (
      current.x === previous.x &&
      current.y === previous.y &&
      current.width === previous.width &&
      current.height === previous.height
    ) {
      return current;
    }
    previous = current;
  }
  return previous;
}

/**
 * Android only: swipe the screen until an element matching `selector` sits in
 * the middle band of the window, clear of the top bar and the gesture area, and
 * return the first such match. On iOS the first match is returned as is
 * (Flutter keeps off-screen nodes there).
 */
export async function scrollIntoView(
  selector: string,
  maxSwipes = 8
): Promise<WebdriverIO.Element> {
  if (!isAndroid()) {
    return $(selector);
  }
  const window = await driver.getWindowRect();
  const top = window.height * 0.15;
  const bottom = window.height * 0.85;
  for (let attempt = 0; attempt <= maxSwipes; attempt += 1) {
    let anyBelow = false;
    let anyAbove = false;
    for (const element of await $$(selector)) {
      const rect = await driver.getElementRect(await element.elementId);
      const centerY = rect.y + rect.height / 2;
      if (centerY >= top && centerY <= bottom) {
        return element;
      }
      if (centerY > bottom) anyBelow = true;
      else anyAbove = true;
    }
    if (attempt === maxSwipes) break;
    // Swipe up (content moves up) to reach matches below, or when nothing
    // matches yet; swipe down only when every match is above the band.
    const direction = anyAbove && !anyBelow ? "down" : "up";
    await driver.execute("mobile: swipeGesture", {
      left: Math.round(window.width * 0.1),
      top: Math.round(window.height * 0.3),
      width: Math.round(window.width * 0.8),
      height: Math.round(window.height * 0.4),
      direction,
      percent: 0.5
    });
    await driver.pause(400);
  }
  throw new Error(`Element '${selector}' did not scroll into view.`);
}
