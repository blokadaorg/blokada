import { driver } from "@wdio/globals";
import { expect } from "chai";

const STALENESS_PATTERNS: RegExp[] = [
  /Failed setting fallback/i,
  /Decoding Fallback Paywalls/i,
  /fallback paywalls version is not correct/i,
  /code:\s*2006\b/i,
];

export async function assertAdaptyFallbackHealthy(): Promise<void> {
  // Adapty SDK emits 2006 to OSLog at setFallbackPaywalls() time, which runs
  // during PaymentActor init at app boot — see adapty.dart:38. A short pause
  // here lets the Dart catch flush its "Failed setting fallback" line too.
  await driver.pause(1500);

  // Session-scoped syslog buffer from appium-xcuitest-driver
  // (via appium-ios-device). Bypasses the CoreDevice app-group provisioning
  // path that breaks pullRecentDeviceLog with Code 1002.
  const logs = await driver.getLogs("syslog");
  const text = (Array.isArray(logs) ? logs : [logs])
    .map((entry) => {
      if (typeof entry === "string") return entry;
      if (entry && typeof entry === "object") {
        const message = (entry as { message?: unknown }).message;
        if (typeof message === "string") return message;
      }
      return JSON.stringify(entry);
    })
    .join("\n");

  const hits = STALENESS_PATTERNS
    .map((re) => text.match(re)?.[0])
    .filter((m): m is string => Boolean(m));

  expect(
    hits,
    "Adapty fallback paywalls JSON appears stale — SDK rejected it on init. " +
      "Refresh from Adapty Dashboard:\n" +
      "  common/assets/fallbacks/ios.json\n" +
      "  common/assets/fallbacks/android.json\n" +
      "  android/app/src/main/assets/fallbacks/android.json\n" +
      `Log matches: ${hits.join("; ")}`,
  ).to.be.empty;
}
