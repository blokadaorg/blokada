import 'package:common/src/platform/stats/api.dart' show JsonToplistEntry;

/// Stats as the screens draw them: one device's counters, the hourly
/// histogram of the last 24 hours, and its toplist. Shared by Blokada 6
/// (StatsStore) and Family (StatsActor), so it lives outside both.
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
  /// Display name of the domain's owner, when known. Never a key.
  final String? company;

  /// The domain this entry counts. Key for navigation, deltas and favicons.
  final String? tld;
  final bool blocked;
  final int value;

  UiToplistEntry(this.company, this.tld, this.blocked, this.value);

  /// Builds an entry from a v2 toplist entry: keyed by the domain, labelled
  /// with the server-provided company name when there is one.
  factory UiToplistEntry.fromV2(JsonToplistEntry entry, {required bool blocked}) {
    final companyName = entry.company?.name?.trim();
    return UiToplistEntry(
      companyName == null || companyName.isEmpty ? null : companyName,
      entry.name,
      blocked,
      entry.count,
    );
  }

  /// Key for navigation, delta matching and favicons. Falls back to [company]
  /// only for entries without a domain (sample data).
  String get domain => tld ?? company ?? "";

  /// Label shown for the row.
  String get displayName => company ?? tld ?? "";
}

/// Sums entries of the same domain (e.g. allowed + fallthrough), sorted by
/// count descending. Keeps the first known company name per domain.
List<UiToplistEntry> mergeToplistEntriesByDomain(Iterable<UiToplistEntry> entries) {
  final merged = <String, UiToplistEntry>{};
  for (final e in entries) {
    final key = e.domain.toLowerCase();
    final existing = merged[key];
    merged[key] = existing == null
        ? e
        : UiToplistEntry(
            existing.company ?? e.company,
            existing.tld ?? e.tld,
            e.blocked,
            existing.value + e.value,
          );
  }
  return merged.values.toList()..sort((a, b) => b.value.compareTo(a.value));
}
