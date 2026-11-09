part of 'home.dart';

/// Where a store free trial is, for the trial line on the daily Home (#460):
/// "Day 3 of 7".
class TrialProgress {
  /// 1-based calendar day of the trial, in the device's time zone.
  final int day;

  /// Trial length in days.
  final int length;

  /// When the trial started, for summing what was blocked since.
  final DateTime startedAt;

  const TrialProgress({required this.day, required this.length, required this.startedAt});

  @override
  bool operator ==(Object other) =>
      other is TrialProgress &&
      other.day == day &&
      other.length == length &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(day, length, startedAt);
}

/// Longest trial the line is shown for; anything longer is not one of our
/// trials (a lifetime level, an odd offer) and gets no line.
const _maxTrialDays = 31;

/// The trial among the store's active access levels, or null when none is a
/// free trial. Only the introductory free trial counts: promotional free
/// periods (win-back offers) have their own lengths and are not the trial the
/// experiment measures. Web (Stripe) trials are not in the store and get no
/// line.
///
/// Days follow local midnight, so "Day 2" starts at midnight rather than at
/// the hour the trial began.
TrialProgress? resolveTrialProgress(
  List<StoreSubscription> subscriptions, {
  required String accountId,
  required DateTime now,
}) {
  for (final sub in subscriptions) {
    if (!sub.isFreeTrial) continue;
    // Levels read right after an account switch may still be the old account's.
    final owner = sub.customerUserId;
    if (owner != null && owner != accountId) continue;
    final start = sub.activatedAt;
    final end = sub.expiresAt;
    if (start == null || end == null || !end.isAfter(start)) continue;

    final length = (end.difference(start).inHours / 24).round();
    if (length < 1 || length > _maxTrialDays) continue;

    final day = _calendarDaysBetween(start.toLocal(), now.toLocal()) + 1;
    return TrialProgress(day: day.clamp(1, length), length: length, startedAt: start);
  }
  return null;
}

/// Whole calendar days from [from] to [to], ignoring the time of day and
/// daylight saving changes.
int _calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}
