import 'dart:convert';
import 'dart:io';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';

void main() {
  // The notification body is assembled from i18n keys, and unit tests load no
  // asset bundle, so `.i18n` would echo the keys back. Feed the real shipped
  // English table in so the assertions below cover the actual copy.
  setUpAll(() {
    final source = File("assets/translations/ui/en.json").readAsStringSync();
    I18nService.translations += {
      "en": Map<String, String>.from(jsonDecode(source)),
    };
    // The table is keyed by language ("en"), so resolving the test locale
    // ("en-US") goes through the fallback and would log a miss per lookup.
    Translations.missingTranslationCallback = (
            {required key,
            required locale,
            required translations,
            required supportedLocales}) =>
        false;
  });

  group("resolveRescueDays", () {
    final now = DateTime(2026, 8, 24, 20);

    test("rounds up partial days", () {
      expect(resolveRescueDays(now.add(const Duration(days: 6, hours: 3)), now), 7);
    });

    test("returns null when already expired or unknown", () {
      expect(resolveRescueDays(now.subtract(const Duration(hours: 1)), now), isNull);
      expect(resolveRescueDays(null, now), isNull);
    });

    test("returns null when less than a day is left, to avoid 'in 0 days'", () {
      expect(resolveRescueDays(now.add(const Duration(seconds: 30)), now), isNull);
    });

    test("returns null when expiry is beyond the rescue window (renewed after send)", () {
      expect(resolveRescueDays(now.add(const Duration(days: 40)), now), isNull);
    });
  });

  group("resolveRescueDevices", () {
    test("keeps a positive count", () {
      expect(resolveRescueDevices("3"), "3");
    });

    test("falls back to one device for missing, zero or non-numeric values", () {
      expect(resolveRescueDevices(null), "1");
      expect(resolveRescueDevices("null"), "1");
      expect(resolveRescueDevices("0"), "1");
      expect(resolveRescueDevices("abc"), "1");
    });
  });

  group("buildAccountRescueBody", () {
    test("includes blocked count when available", () {
      final json = jsonDecode(buildAccountRescueBody(totalBlocked: 12345, devices: "3", days: 7));
      expect(json["title"], "Your protection ends soon");
      expect(json["body"],
          "Blokada has blocked 12345 ads and trackers since you set it up. Protection on 3 devices ends in 7 days.");
    });

    test("falls back to the short body without stats", () {
      final json = jsonDecode(buildAccountRescueBody(totalBlocked: null, devices: "1", days: 2));
      expect(json["body"], "Protection on 1 devices ends in 2 days.");
    });
  });

  test("FcmEvent.extrasMap decodes the JSON string extras", () {
    final event = FcmEvent.fromJson({
      "v": "1",
      "type": "account_rescue",
      "event_id": "e1",
      "extras": '{"devices":"3"}',
    });
    expect(event.extrasMap["devices"], "3");
    expect(FcmEvent.fromJson({"type": "x"}).extrasMap, isEmpty);
  });

  test("Placement.winback id matches the Adapty dashboard placement", () {
    expect(Placement.winback.id, "winback");
  });
}
