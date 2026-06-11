part of 'schedule.dart';

/// English short day labels for custom day sets, indexed 1..7 (Mon..Sun per
/// ISO 8601). Custom day-set summaries (e.g. `[Mon, Wed, Fri]`) still render
/// in English; localising the individual day labels needs a fresh i18n key
/// surface and is out of scope for this commit.
const _shortDayLabels = <int, String>{
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

/// Coarse bucket for a weekday set. The editor renders these as preset chips
/// (Weekdays / Weekends / Every day / Custom). [custom] is the catch-all for
/// any subset that doesn't exactly match one of the canonical presets.
enum WeekdayPreset { weekdays, weekends, every, custom }

/// Map a weekday set to its preset bucket. Order-insensitive. Empty and
/// non-canonical subsets return [WeekdayPreset.custom] so the editor sheet
/// keeps the user's bespoke selection visible without snapping it.
WeekdayPreset presetForWeekdays(List<int> weekdays) {
  final set = weekdays.toSet();
  if (set.length == 5 && set.containsAll(const {1, 2, 3, 4, 5})) {
    return WeekdayPreset.weekdays;
  }
  if (set.length == 2 && set.containsAll(const {6, 7})) {
    return WeekdayPreset.weekends;
  }
  if (set.length == 7) return WeekdayPreset.every;
  return WeekdayPreset.custom;
}

/// Inverse of [presetForWeekdays]. [WeekdayPreset.custom] is caller-defined,
/// so this returns an empty list — the editor sheet preserves the user's
/// current selection when the user picks "Custom".
List<int> weekdaysForPreset(WeekdayPreset preset) {
  switch (preset) {
    case WeekdayPreset.weekdays:
      return const [1, 2, 3, 4, 5];
    case WeekdayPreset.weekends:
      return const [6, 7];
    case WeekdayPreset.every:
      return const [1, 2, 3, 4, 5, 6, 7];
    case WeekdayPreset.custom:
      return const [];
  }
}

/// Render a weekday set as the row-summary string. Canonical presets route
/// through the `family schedule days summary {weekdays,weekends,every}` i18n
/// keys so non-English locales render their own labels; custom sets join the
/// English short labels with ", " in ISO order (see note on [_shortDayLabels]).
String daysSummary(List<int> weekdays) {
  switch (presetForWeekdays(weekdays)) {
    case WeekdayPreset.weekdays:
      return 'family schedule days summary weekdays'.i18n;
    case WeekdayPreset.weekends:
      return 'family schedule days summary weekends'.i18n;
    case WeekdayPreset.every:
      return 'family schedule days summary every'.i18n;
    case WeekdayPreset.custom:
      final sorted = [...weekdays]..sort();
      return sorted.map((d) => _shortDayLabels[d] ?? '?').join(', ');
  }
}

/// Render a 0..1439 minute as HH:mm zero-padded.
String formatMinuteOfDay(int minute) {
  final hh = (minute ~/ 60).toString().padLeft(2, '0');
  final mm = (minute % 60).toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Render a list of [TimeWindowModel] as the row-summary string. Shows up to
/// two windows verbatim; appends the localised `family schedule rule row more`
/// suffix (which carries the leading ", +" plus the localised "more" word) for
/// any further windows. Wraparound windows render the same way ("21:00–07:00");
/// the "↳ ends next day" hint lives in the editor sheet, not in the row.
String windowsSummary(List<TimeWindowModel> windows) {
  String render(TimeWindowModel w) =>
      '${formatMinuteOfDay(w.startMinute)}–${formatMinuteOfDay(w.endMinute)}';
  if (windows.length <= 2) return windows.map(render).join(', ');
  final visible = windows.take(2).map(render).join(', ');
  final remaining = windows.length - 2;
  return visible +
      'family schedule rule row more'.i18n.withParams(remaining.toString());
}
