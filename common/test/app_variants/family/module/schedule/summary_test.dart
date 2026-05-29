import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatMinuteOfDay', () {
    test('zero pads hours and minutes', () {
      expect(formatMinuteOfDay(0), '00:00');
      expect(formatMinuteOfDay(60), '01:00');
      expect(formatMinuteOfDay(510), '08:30');
      expect(formatMinuteOfDay(1439), '23:59');
    });
  });

  group('presetForWeekdays', () {
    test('1..5 → weekdays', () {
      expect(presetForWeekdays(const [1, 2, 3, 4, 5]), WeekdayPreset.weekdays);
    });

    test('6,7 → weekends', () {
      expect(presetForWeekdays(const [6, 7]), WeekdayPreset.weekends);
    });

    test('1..7 → every', () {
      expect(presetForWeekdays(const [1, 2, 3, 4, 5, 6, 7]),
          WeekdayPreset.every);
    });

    test('order does not matter', () {
      expect(presetForWeekdays(const [5, 4, 3, 2, 1]), WeekdayPreset.weekdays);
    });

    test('partial sets → custom', () {
      expect(presetForWeekdays(const [1, 3, 5]), WeekdayPreset.custom);
      expect(presetForWeekdays(const [1]), WeekdayPreset.custom);
      expect(presetForWeekdays(const []), WeekdayPreset.custom);
    });
  });

  group('weekdaysForPreset', () {
    test('produces the expected sets', () {
      expect(weekdaysForPreset(WeekdayPreset.weekdays), [1, 2, 3, 4, 5]);
      expect(weekdaysForPreset(WeekdayPreset.weekends), [6, 7]);
      expect(weekdaysForPreset(WeekdayPreset.every), [1, 2, 3, 4, 5, 6, 7]);
      // custom: caller-defined; helper returns empty
      expect(weekdaysForPreset(WeekdayPreset.custom), <int>[]);
    });
  });

  group('daysSummary', () {
    test('canonical presets resolve through the days summary i18n keys', () {
      // In the test env the i18n extension returns the key verbatim because
      // no localisation table is loaded — what matters here is that the
      // canonical preset branches route through the key surface rather than
      // returning hard-coded English; in-app the localisation table picks up
      // each locale's translation (e.g. Swedish "Mån–Fre" / "Lör–Sön").
      expect(daysSummary(const [1, 2, 3, 4, 5]),
          'family schedule days summary weekdays');
      expect(daysSummary(const [6, 7]),
          'family schedule days summary weekends');
      expect(daysSummary(const [1, 2, 3, 4, 5, 6, 7]),
          'family schedule days summary every');
    });

    test('custom sets join the English short labels with commas', () {
      expect(daysSummary(const [1, 3, 5]), 'Mon, Wed, Fri');
      expect(daysSummary(const [2, 4]), 'Tue, Thu');
    });
  });

  group('windowsSummary', () {
    test('single window renders as HH:mm–HH:mm', () {
      final s = windowsSummary(const [
        TimeWindowModel(startMinute: 510, endMinute: 900),
      ]);
      expect(s, '08:30–15:00');
    });

    test('two windows render comma-joined', () {
      final s = windowsSummary(const [
        TimeWindowModel(startMinute: 510, endMinute: 720),
        TimeWindowModel(startMinute: 780, endMinute: 930),
      ]);
      expect(s, '08:30–12:00, 13:00–15:30');
    });

    test('three or more windows truncate to two + the localised more suffix',
        () {
      final s = windowsSummary(const [
        TimeWindowModel(startMinute: 60, endMinute: 120),
        TimeWindowModel(startMinute: 180, endMinute: 240),
        TimeWindowModel(startMinute: 300, endMinute: 360),
        TimeWindowModel(startMinute: 420, endMinute: 480),
      ]);
      // First two windows render verbatim; the trailing "+N more" suffix
      // is routed through the i18n key surface so non-English locales pick
      // up their own translation (e.g. Swedish ", +N till"). In the test env
      // the key resolves verbatim and the integer count is appended.
      expect(s, startsWith('01:00–02:00, 03:00–04:00'));
      expect(s, contains('family schedule rule row more'));
    });
  });
}
