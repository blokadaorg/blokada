part of 'home.dart';

/// A store free trial, for the trial line on the daily Home (#460):
/// "Day 3 of 7". The day is worked out when drawn, so it moves on at midnight
/// while Home stays open.
class TrialProgress {
  /// Trial length in days.
  final int length;

  /// When the trial started, for the day and for summing what was blocked.
  final DateTime startedAt;

  const TrialProgress({required this.length, required this.startedAt});

  /// 1-based calendar day of the trial on [now], in the device's time zone,
  /// clamped to the trial.
  int dayOn(DateTime now) =>
      (_calendarDaysBetween(startedAt.toLocal(), now.toLocal()) + 1).clamp(1, length);

  @override
  bool operator ==(Object other) =>
      other is TrialProgress && other.length == length && other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(length, startedAt);
}

/// Stores whose access levels are app store purchases. Web purchases also
/// reach Adapty, but their trials are not the store trial measured here.
const _storeIds = {'app_store', 'play_store'};

/// Longest trial the line is shown for; anything longer is not one of our
/// trials (a lifetime level, an odd offer) and gets no line.
const _maxTrialDays = 31;

/// The trial among the store's active access levels, or null when none is a
/// free trial. Only the introductory free trial from the App Store or Google
/// Play counts: promotional free periods (win-back offers) have their own
/// lengths, and web trials are not the trial the experiment measures.
TrialProgress? resolveTrialProgress(
  List<StoreSubscription> subscriptions, {
  required String accountId,
}) {
  for (final sub in subscriptions) {
    if (!sub.isFreeTrial || !_storeIds.contains(sub.store)) continue;
    // Levels read right after an account switch may still be the old account's.
    final owner = sub.customerUserId;
    if (owner != null && owner != accountId) continue;
    final start = sub.activatedAt;
    final end = sub.expiresAt;
    if (start == null || end == null || !end.isAfter(start)) continue;

    final length = (end.difference(start).inHours / 24).round();
    if (length < 1 || length > _maxTrialDays) continue;

    return TrialProgress(length: length, startedAt: start);
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

/// Blocked since the trial started: the daily buckets since then, but at
/// least the last 24 hours from the hourly [day] stats, because a day's
/// bucket appears only after a lag and a new trial would otherwise read 0.
/// Before a trial the account had no DNS blocking, so the 24 hours do not
/// count blocks from before it.
int trialBlockedSoFar(int dailySince, UiStats? day) {
  final last24h = day?.dayBlocked ?? 0;
  return dailySince > last24h ? dailySince : last24h;
}
