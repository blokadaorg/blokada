part of 'schedule.dart';

/// Result of resolving which rule is firing at a given instant.
///
/// Carries the index of the active rule within [ScheduleModel.rules] (list
/// order, so callers can highlight the same row) and the [endMinute] of the
/// matched window so the UI can render "until HH:MM". A `null` result from
/// [activeRuleForSchedule] means no rule is firing (paused, no match, or no
/// rules) and the device's default profile applies.
class ActiveRule {
  /// Index into [ScheduleModel.rules] of the firing rule.
  final int ruleIndex;

  /// The firing rule.
  final RuleModel rule;

  /// `endMinute` of the window that matched, in 0..1439 device-local minutes.
  /// For a wraparound window this is the next-day end (e.g. 420 for 07:00).
  final int endMinute;

  const ActiveRule({
    required this.ruleIndex,
    required this.rule,
    required this.endMinute,
  });
}

/// Client-side mirror of the api/resolver's `active_profile_for_schedule`
/// (see `blockarust/src/schedule.rs`). Returns the first rule, in list order,
/// one of whose [RuleModel.windows] covers the current ISO weekday +
/// minute-of-day — together with that window's `endMinute`. A wrap-around
/// window (21:00–07:00) is owned by the weekday it *starts* on, so its
/// early-morning carry-over matches when the *previous* ISO day is in the
/// rule's weekday set (see [_windowMatches], kept in sync with `_ruleMatches`
/// in `module/schedule/resolver.dart`). Returns null when [ScheduleModel.paused]
/// is true, no rule matches, or there are no rules; the caller falls back to
/// the device's default profile.
///
/// Pure: no I/O. [now] is the device-local time (`DateTime.now()` for the
/// app). `now.weekday` is already ISO 1=Mon..7=Sun, matching the wire format.
/// Cross-timezone drift (parent clock vs device clock) is accepted for v1 —
/// see the design doc's Out-of-scope list.
ActiveRule? activeRuleForSchedule(ScheduleModel schedule, DateTime now) {
  if (schedule.paused) return null;

  final isoWeekday = now.weekday; // Dart: Mon=1..Sun=7, matches ISO 8601.
  final minuteOfDay = now.hour * 60 + now.minute;

  for (var i = 0; i < schedule.rules.length; i++) {
    final rule = schedule.rules[i];
    for (final window in rule.windows) {
      if (_windowMatches(rule, window, isoWeekday, minuteOfDay)) {
        return ActiveRule(
          ruleIndex: i,
          rule: rule,
          endMinute: window.endMinute,
        );
      }
    }
  }
  return null;
}

/// True when [window] of [rule] covers [isoWeekday] (1..7) at [minuteOfDay]
/// (0..1439). Mirrors `_ruleMatches` in `module/schedule/resolver.dart` so the
/// two client resolvers agree; keep them in sync.
///
/// A non-wrap window `[start, end)` matches iff the rule lists today and the
/// minute is in range. `start == end` is a zero-length no-match (`endMinute <
/// startMinute` is false, so it falls through the non-wrap branch).
///
/// A wrap window (`endMinute < startMinute`, e.g. 21:00–07:00) is owned by the
/// weekday it *starts* on. The late-evening half `[start, 1439]` matches on the
/// rule's listed weekday; the early-morning carry-over half `[0, end)` belongs
/// to the *next* calendar day, so it matches when the *previous* ISO day is in
/// the rule's weekday set. Without this, a single-weekday wrap rule would miss
/// its own next-morning tail.
bool _windowMatches(
  RuleModel rule,
  TimeWindowModel w,
  int isoWeekday,
  int minute,
) {
  if (w.wrapsToNextDay) {
    if (rule.weekdays.contains(isoWeekday) && minute >= w.startMinute) {
      return true;
    }
    final previousDay = isoWeekday == 1 ? 7 : isoWeekday - 1;
    return rule.weekdays.contains(previousDay) && minute < w.endMinute;
  }
  return rule.weekdays.contains(isoWeekday) &&
      minute >= w.startMinute &&
      minute < w.endMinute;
}
