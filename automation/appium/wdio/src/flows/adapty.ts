import { driver } from "@wdio/globals";
import { expect } from "chai";

const STALENESS_PATTERNS: RegExp[] = [
  /Failed setting fallback/i,
  /Decoding Fallback Paywalls/i,
  /fallback paywalls version is not correct/i,
  /code:\s*2006\b/i,
];

type PullRecentDeviceLog = (options: Record<string, unknown>) => Promise<{ text: string }>;

export async function assertAdaptyFallbackHealthy(bundleId: string): Promise<void> {
  // Give the catch in common/lib/src/features/payment/domain/adapty.dart:39
  // time to flush the failure line to the in-app share-log.
  await driver.pause(1500);

  const caps = driver.capabilities as Record<string, unknown>;
  const udid = (caps["appium:udid"] ?? caps["udid"]) as string | undefined;
  if (!udid) {
    throw new Error("Adapty fallback check: no UDID in wdio capabilities");
  }

  const logModule = (await import("../../../../device/lib/log.mjs")) as {
    pullRecentDeviceLog: PullRecentDeviceLog;
  };

  const { text } = await logModule.pullRecentDeviceLog({
    bundleId,
    device: { udid },
    window: "1h",
    lines: 2000,
    save: false,
  });

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
