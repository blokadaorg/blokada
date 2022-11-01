import 'dart:math';

class UiStats {

  final int totalAllowed;
  final int totalBlocked;

  final List<int> allowedHistogram;
  final List<int> blockedHistogram;

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
    required this.totalAllowed, required this.totalBlocked,
    required this.allowedHistogram, required this.blockedHistogram,
    required this.avgDayTotal, required this.avgDayAllowed, required this.avgDayBlocked,
    required this.latestTimestamp,
  }) {
    dayAllowed = allowedHistogram.reduce((a, b) => a + b);
    dayBlocked = blockedHistogram.reduce((a, b) => a + b);
    dayTotal = dayAllowed + dayBlocked;

    // dayAllowedRatio = ((dayAllowed / avgDayAllowed) * 100);
    // dayBlockedRatio = ((dayBlocked / avgDayBlocked) * 100);
    dayTotalRatio = dayAllowedRatio + dayBlockedRatio; // As per Johnny request, to make total ring always bigger than others
  }

  UiStats.empty({
    this.totalAllowed = 0, this.totalBlocked = 0,
    this.allowedHistogram = const [], this.blockedHistogram = const [],
  });

}

class UiStatsPair {
  final DateTime timestamp;
  final int value;

  UiStatsPair({required this.timestamp, required this.value});
}