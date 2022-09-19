class UiStats {

  final int totalAllowed;
  final int totalBlocked;

  final List<int> allowedHistogram;
  final List<int> blockedHistogram;

  int latestTimestamp = DateTime.now().millisecondsSinceEpoch;

  int hourlyAllowed = 0;
  int hourlyBlocked = 0;

  int rateAllowed = 0;
  int rateBlocked = 0;
  int rateTotal = 0;

  int avgAllowed = 0;
  int avgBlocked = 0;
  int avgTotal = 0;

  UiStats({
    required this.totalAllowed, required this.totalBlocked,
    required this.allowedHistogram, required this.blockedHistogram,
    required this.latestTimestamp,
  }) {
    hourlyAllowed = allowedHistogram.reduce((a, b) => a + b);
    hourlyBlocked = blockedHistogram.reduce((a, b) => a + b);

    rateAllowed = allowedHistogram.last;
    rateBlocked = blockedHistogram.last;
    rateTotal = rateAllowed + rateBlocked;

    avgAllowed = (hourlyAllowed / 24.0).round();
    avgBlocked = (hourlyBlocked / 24.0).round();
    avgTotal = ((hourlyBlocked + hourlyAllowed) / 24.0).round();
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