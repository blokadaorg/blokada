class UiStats {

  final int totalAllowed;
  final int totalBlocked;

  final List<int> allowedHistogram;
  final List<int> blockedHistogram;

  final int hourlyAllowed;
  final int hourlyBlocked;

  UiStats({
    required this.totalAllowed, required this.totalBlocked,
    required this.allowedHistogram, required this.blockedHistogram,
    required this.hourlyAllowed, required this.hourlyBlocked
  });

  UiStats.empty({
    this.totalAllowed = 0, this.totalBlocked = 0,
    this.allowedHistogram = const [], this.blockedHistogram = const [],
    this.hourlyAllowed = 0, this.hourlyBlocked = 0
  });

}