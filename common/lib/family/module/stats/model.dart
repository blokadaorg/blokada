part of 'stats.dart';

class UiStats {
  final int totalAllowed;
  final int totalBlocked;

  final List<int> allowedHistogram;
  final List<int> blockedHistogram;

  final List<UiToplistEntry> toplist;

  int latestTimestamp = DateTime.now().millisecondsSinceEpoch;

  // Sum for the current day
  int dayAllowed = 0;
  int dayBlocked = 0;
  int dayTotal = 0;

  // Average values per day (taken from at least a week of data)
  int avgDayAllowed = 0;
  int avgDayBlocked = 0;
  int avgDayTotal = 0;

  // Value 0-100 meaning what % of the average daily is the value for the current day
  double dayAllowedRatio = 0;
  double dayBlockedRatio = 0;
  double dayTotalRatio = 0;

  UiStats({
    required this.totalAllowed,
    required this.totalBlocked,
    required this.allowedHistogram,
    required this.blockedHistogram,
    required this.toplist,
    required this.avgDayTotal,
    required this.avgDayAllowed,
    required this.avgDayBlocked,
    required this.latestTimestamp,
  }) {
    dayAllowed = allowedHistogram.reduce((a, b) => a + b);
    dayBlocked = blockedHistogram.reduce((a, b) => a + b);
    dayTotal = dayAllowed + dayBlocked;

    double _safeRatio(int numerator, int denominator) {
      if (denominator == 0) return 0;
      return (numerator / denominator) * 100;
    }

    dayAllowedRatio = _safeRatio(dayAllowed, avgDayAllowed).clamp(0, 100);
    dayBlockedRatio = _safeRatio(dayBlocked, avgDayBlocked).clamp(0, 100);
    dayTotalRatio = (dayAllowedRatio + dayBlockedRatio).clamp(0, 100);
  }

  UiStats.empty({
    this.totalAllowed = 0,
    this.totalBlocked = 0,
    this.allowedHistogram = const [],
    this.blockedHistogram = const [],
    this.toplist = const [],
  });
}

class UiToplistEntry {
  final String? company;
  final String? tld;
  final bool blocked;
  final int value;

  UiToplistEntry(this.company, this.tld, this.blocked, this.value);
}
