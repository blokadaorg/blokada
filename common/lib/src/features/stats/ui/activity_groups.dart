import 'package:common/src/core/core.dart';
import 'package:intl/intl.dart';

/// When an Activity entry happened, as the list groups it. A long log is
/// easier to scan in a few time groups than as one undivided list.
enum ActivityPeriod { justNow, earlierToday, yesterday, older }

/// Entries from the last hour count as just now, even across midnight.
const activityJustNow = Duration(hours: 1);

/// The group of an entry at [at], seen at [now]; days are local days.
ActivityPeriod activityPeriodOf(DateTime at, DateTime now) {
  final local = at.toLocal();
  final today = now.toLocal();
  if (today.difference(local) < activityJustNow) return ActivityPeriod.justNow;
  final day = DateTime(local.year, local.month, local.day);
  final midnight = DateTime(today.year, today.month, today.day);
  if (!day.isBefore(midnight)) return ActivityPeriod.earlierToday;
  // Calendar arithmetic, so a DST change doesn't move the day.
  if (day == DateTime(today.year, today.month, today.day - 1)) return ActivityPeriod.yesterday;
  return ActivityPeriod.older;
}

/// The group header for an entry at [at]: "Just now", "Earlier today",
/// "Yesterday", or the date ("Mon, Oct 20"; with the year if not this one).
String activityGroupLabel(DateTime at, DateTime now, String locale) {
  switch (activityPeriodOf(at, now)) {
    case ActivityPeriod.justNow:
      return "activity group just now".i18n;
    case ActivityPeriod.earlierToday:
      return "activity group earlier today".i18n;
    case ActivityPeriod.yesterday:
      return "activity group yesterday".i18n;
    case ActivityPeriod.older:
      return _formatDay(at.toLocal(), now.toLocal(), locale);
  }
}

/// [activityGroupLabel] for a whole list, formatting each older day once,
/// as a long log has many rows per day.
List<String> activityGroupLabels(Iterable<DateTime> times, DateTime now, String locale) {
  final days = <DateTime, String>{};
  return times.map((at) {
    if (activityPeriodOf(at, now) != ActivityPeriod.older) {
      return activityGroupLabel(at, now, locale);
    }
    final local = at.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return days[day] ??= _formatDay(day, now.toLocal(), locale);
  }).toList();
}

String _formatDay(DateTime day, DateTime now, String locale) {
  final withYear = day.year != now.year;
  DateFormat format(String loc) => withYear ? DateFormat.yMMMEd(loc) : DateFormat.MMMEd(loc);
  // intl throws when it has no date data for the locale (ArgumentError) or
  // none loaded at all (LocaleDataException, not exported); en_US is built in.
  try {
    return format(locale).format(day);
  } on ArgumentError {
    return format("en_US").format(day);
  } on Exception {
    return format("en_US").format(day);
  }
}
