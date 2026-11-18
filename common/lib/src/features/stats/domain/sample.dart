import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Made-up numbers for Privacy Pulse and Activity while activity logging is
/// off, shown blurred behind the offer to turn it on. Same names as the
/// freemium sample, but fixed, so the preview looks the same every time.
class LoggingSample {
  LoggingSample._();

  // A day's shape, per hour, oldest first.
  static const _allowedPerHour = [
    90, 40, 20, 15, 15, 30, 120, 260, 340, 310, 280, 300, //
    330, 310, 290, 300, 340, 380, 420, 400, 360, 300, 220, 150,
  ];
  static const _blockedPerHour = [
    30, 12, 6, 5, 5, 10, 40, 90, 120, 110, 95, 100, //
    115, 105, 100, 105, 120, 135, 150, 140, 125, 100, 75, 50,
  ];
  static const _blockedCounts = [1240, 860, 520];
  static const _allowedCounts = [3900, 2100, 980];

  static UiStats stats({DateTime? now}) => UiStats(
    totalAllowed: 48121,
    totalBlocked: 15734,
    allowedHistogram: _allowedPerHour,
    blockedHistogram: _blockedPerHour,
    toplist: const [],
    avgDayTotal: 7900,
    avgDayAllowed: 5800,
    avgDayBlocked: 2100,
    latestTimestamp: (now ?? DateTime.now()).millisecondsSinceEpoch,
  );

  static PulseCounters counters(ToplistRange range, {DateTime? now}) {
    final day = stats(now: now);
    final days = range == ToplistRange.weekly ? 7 : 1;
    return PulseCounters(
      counters: StatsCounters(
        allowed: day.dayAllowed * days,
        blocked: day.dayBlocked * days,
        total: day.dayTotal * days,
      ),
      delta: null,
      deltaReady: true,
      sparkline: range == ToplistRange.weekly
          ? DailySeries(
              values: [
                for (final f in const [0.9, 1.1, 1.0, 0.8, 1.2, 1.05, 1.0])
                  (day.dayAllowed * f).round(),
              ],
              end: now ?? DateTime.now(),
              step: const Duration(days: 1),
            )
          : null,
    );
  }

  static PulseToplists toplists(ToplistRange range) {
    final days = range == ToplistRange.weekly ? 7 : 1;
    return PulseToplists(
      entries: [
        for (var i = 0; i < _blockedCounts.length; i++)
          UiToplistEntry(
            FreemiumDataProvider.sampleBlockedCompanies[i],
            null,
            true,
            _blockedCounts[i] * days,
          ),
        for (var i = 0; i < _allowedCounts.length; i++)
          UiToplistEntry(
            FreemiumDataProvider.sampleAllowedCompanies[i],
            null,
            false,
            _allowedCounts[i] * days,
          ),
      ],
      blockedDeltas: null,
      allowedDeltas: null,
    );
  }

  /// Recent requests, newest first, alternating blocked and allowed.
  static List<UiJournalEntry> journal({int count = 12, DateTime? now}) {
    final at = now ?? DateTime.now();
    const domains = FreemiumDataProvider.sampleJournalDomains;
    return [
      for (var i = 0; i < count; i++)
        UiJournalEntry(
          deviceName: "",
          domainName: domains[i % domains.length],
          action: i.isEven ? UiJournalAction.block : UiJournalAction.allow,
          listId: "",
          profileId: null,
          timestamp: at.subtract(Duration(minutes: 3 * i + 1)),
        )..timestampText = timeago.format(at.subtract(Duration(minutes: 3 * i + 1))),
    ];
  }

  static RecentPreview recent({DateTime? now}) {
    final entries = journal(count: 10, now: now);
    return RecentPreview(
      blocked: entries.where((e) => e.isBlocked()).take(5).toList(),
      allowed: entries.where((e) => !e.isBlocked()).take(5).toList(),
    );
  }
}

/// A [StatsController] that holds [LoggingSample] and fetches nothing, so
/// Privacy Pulse can draw the preview with its usual sections.
class SampleStatsController extends StatsController {
  SampleStatsController() {
    _publish(ToplistRange.daily);
  }

  void _publish(ToplistRange next) {
    range.now = next;
    stats.now = StatsSection(StatsStatus.ready, LoggingSample.stats());
    counters.now = StatsSection(StatsStatus.ready, LoggingSample.counters(next));
    toplists.now = StatsSection(StatsStatus.ready, LoggingSample.toplists(next));
    recent.now = StatsSection(StatsStatus.ready, LoggingSample.recent());
  }

  @override
  Future<void> openPulse(Marker m, {ToplistRange? initialRange}) async {
    _publish(initialRange ?? ToplistRange.daily);
  }

  @override
  void closePulse() {}

  @override
  void setHomeRefresh(bool enabled) {}

  @override
  Future<void> refreshPulse(Marker m) async {}

  @override
  Future<void> setRange(Marker m, ToplistRange next) async => _publish(next);

  @override
  Future<void> retry(Marker m, StatsPart part) async {}
}
