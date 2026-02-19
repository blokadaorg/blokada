class WeeklyComparison {
  final int previous;
  final int current;
  final double percent;
  final bool increased;
  final String? multiplierLabel;

  const WeeklyComparison({
    required this.previous,
    required this.current,
    required this.percent,
    required this.increased,
    required this.multiplierLabel,
  });

  double get absolutePercent => percent.abs();

  int get roundedPercent => percent.round();

  String formatForNotification() {
    if (increased && multiplierLabel != null) {
      return multiplierLabel!;
    }
    final rounded = roundedPercent;
    final sign = rounded > 0 ? '+' : '-';
    return '$sign${rounded.abs()}';
  }

  String formatForCounterLabel() {
    if (increased && multiplierLabel != null) {
      return multiplierLabel!;
    }
    final rounded = roundedPercent;
    if (rounded == 0) return '';
    final sign = rounded > 0 ? '+' : '';
    return '$sign$rounded%';
  }
}

WeeklyComparison compareWeeklyTotals(int previous, int current) {
  final percent = _percentChange(previous, current);
  return WeeklyComparison(
    previous: previous,
    current: current,
    percent: percent,
    increased: percent > 0,
    multiplierLabel: _multiplierLabel(previous, current),
  );
}

double _percentChange(int previous, int current) {
  if (previous == 0) return 0;
  return ((current - previous) / previous) * 100;
}

String? _multiplierLabel(int previous, int current) {
  if (previous <= 0 || current <= previous) return null;
  final multiplier = current / previous;
  if (multiplier < 2) return null;
  return '${multiplier.ceil()}x';
}
