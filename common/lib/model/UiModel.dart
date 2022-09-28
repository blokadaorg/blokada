import 'dart:math';

class UiStats {

  final int totalAllowed;
  final int totalBlocked;

  final List<int> allowedHistogram;
  final List<int> blockedHistogram;

  int latestTimestamp = DateTime.now().millisecondsSinceEpoch;

  int dayAllowed = 0;
  int dayBlocked = 0;
  int dayTotal = 0;

  int rateAllowed = 0;
  int rateBlocked = 0;
  int rateTotal = 0;

  int avgAllowed = 0;
  int avgBlocked = 0;
  int avgTotal = 0;

  int avgDayAllowed = 0;
  int avgDayBlocked = 0;
  int avgDayTotal = 0;

  UiStats({
    required this.totalAllowed, required this.totalBlocked,
    required this.allowedHistogram, required this.blockedHistogram,
    required this.avgDayTotal, required this.avgDayAllowed, required this.avgDayBlocked,
    required this.latestTimestamp,
  }) {
    dayAllowed = allowedHistogram.reduce((a, b) => a + b);
    dayBlocked = blockedHistogram.reduce((a, b) => a + b);
    dayTotal = dayAllowed + dayBlocked;

    // avgDayAllowed = (dayAllowed * 1.1).toInt();
    // avgDayBlocked = (dayBlocked * 1.1).toInt();
    // avgDayTotal = (dayTotal * 1.1).toInt();

    rateAllowed = allowedHistogram.last;
    rateBlocked = blockedHistogram.last;
    rateTotal = rateAllowed + rateBlocked;

    avgAllowed = (dayAllowed / 24.0).round();
    avgBlocked = (dayBlocked / 24.0).round();
    avgTotal = ((dayBlocked + dayAllowed) / 24.0).round();
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