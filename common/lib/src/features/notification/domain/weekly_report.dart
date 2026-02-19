part of 'notification.dart';

const Duration weeklyReportInterval = Duration(minutes: 10);
const Duration weeklyReportBackgroundLead = Duration(minutes: 2);
const bool weeklyReportGenerationEnabled = false; // Temporary kill switch for weekly reports.

const weeklyReportTitleKey = 'notification weekly report title';
const weeklyReportBodyKey = 'notification weekly report body';
const weeklyReportRefreshedTitleKey = 'notification weekly report refreshed title';
const weeklyReportRefreshedBodyKey = 'notification weekly report refreshed body';
const weeklyReportCtaKey = 'notification weekly report cta';

const weeklyReportBlockedIncreasedTitleKey =
    'notification weekly report blocked increased title';
const weeklyReportBlockedDecreasedTitleKey =
    'notification weekly report blocked decreased title';
const weeklyReportAllowedIncreasedTitleKey =
    'notification weekly report allowed increased title';
const weeklyReportAllowedDecreasedTitleKey =
    'notification weekly report allowed decreased title';
const weeklyReportBlockedTotalsBodyKey = 'notification weekly report blocked totals body';
const weeklyReportAllowedTotalsBodyKey = 'notification weekly report allowed totals body';

const weeklyReportBlockedToplistNewTitleKey =
    'notification weekly report blocked toplist new title';
const weeklyReportAllowedToplistNewTitleKey =
    'notification weekly report allowed toplist new title';
const weeklyReportBlockedToplistUpTitleKey =
    'notification weekly report blocked toplist up title';
const weeklyReportAllowedToplistUpTitleKey =
    'notification weekly report allowed toplist up title';
const weeklyReportBlockedToplistDownTitleKey =
    'notification weekly report blocked toplist down title';
const weeklyReportAllowedToplistDownTitleKey =
    'notification weekly report allowed toplist down title';
const weeklyReportToplistNewBodyKey = 'notification weekly report toplist new body';
const weeklyReportToplistMoveBodyKey = 'notification weekly report toplist move body';

class WeeklyReportScheduleValue extends StringifiedPersistedValue<DateTime> {
  WeeklyReportScheduleValue() : super('notification:weekly_report:scheduled_at');

  @override
  DateTime fromStringified(String value) => DateTime.parse(value);

  @override
  String toStringified(DateTime value) => value.toIso8601String();
}

class WeeklyReportLastDismissedValue extends StringPersistedValue {
  WeeklyReportLastDismissedValue() : super('notification:weekly_report:last_dismissed');
}

class WeeklyReportLastScheduledValue extends StringPersistedValue {
  WeeklyReportLastScheduledValue() : super('notification:weekly_report:last_scheduled');
}

class WeeklyReportLastNotifiedValue extends StringPersistedValue {
  WeeklyReportLastNotifiedValue() : super('notification:weekly_report:last_notified');
}

class WeeklyReportOptOutValue extends BoolPersistedValue {
  WeeklyReportOptOutValue() : super('notification:weekly_report:opt_out');
}

class WeeklyReportPendingEventValue
    extends JsonPersistedValue<WeeklyReportPendingEvent> {
  WeeklyReportPendingEventValue()
      : super('notification:weekly_report:pending_event', secure: true);

  @override
  Map<String, dynamic> toJson(WeeklyReportPendingEvent value) => value.toJson();

  @override
  WeeklyReportPendingEvent fromJson(Map<String, dynamic> json) =>
      WeeklyReportPendingEvent.fromJson(json);
}

enum WeeklyReportEventType { toplistChange, totalsDelta, mock }

enum WeeklyReportIcon { chart, shield, trendUp, trendDown }

class WeeklyReportEvent {
  final String id;
  final String title;
  final String body;
  final WeeklyReportEventType type;
  final WeeklyReportIcon icon;
  final double score;
  final DateTime generatedAt;
  final String? ctaLabel;
  final WeeklyReportToplistHighlight? toplistHighlight;
  final String? deltaLabel;
  final bool? deltaIncreased;
  final double? deltaPercent;

  WeeklyReportEvent({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.icon,
    required this.score,
    required this.generatedAt,
    this.ctaLabel,
    this.toplistHighlight,
    this.deltaLabel,
    this.deltaIncreased,
    this.deltaPercent,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'icon': icon.name,
      'score': score,
      'generatedAt': generatedAt.toIso8601String(),
      'ctaLabel': ctaLabel,
      'toplistHighlight': toplistHighlight?.toJson(),
      'deltaLabel': deltaLabel,
      'deltaIncreased': deltaIncreased,
      'deltaPercent': deltaPercent,
    };
  }

  factory WeeklyReportEvent.fromJson(Map<String, dynamic> json) {
    return WeeklyReportEvent(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      type: WeeklyReportEventType.values
          .firstWhere((e) => e.name == json['type'], orElse: () => WeeklyReportEventType.mock),
      icon: WeeklyReportIcon.values
          .firstWhere((e) => e.name == json['icon'], orElse: () => WeeklyReportIcon.chart),
      score: (json['score'] as num).toDouble(),
      generatedAt: DateTime.parse(json['generatedAt']),
      ctaLabel: json['ctaLabel'],
      toplistHighlight: json['toplistHighlight'] != null
          ? WeeklyReportToplistHighlight.fromJson(
              Map<String, dynamic>.from(json['toplistHighlight']))
          : null,
      deltaLabel: json['deltaLabel'],
      deltaIncreased: json['deltaIncreased'],
      deltaPercent: (json['deltaPercent'] as num?)?.toDouble(),
    );
  }

  WeeklyReportEvent copyWith({
    String? id,
    String? title,
    String? body,
    WeeklyReportEventType? type,
    WeeklyReportIcon? icon,
    double? score,
    DateTime? generatedAt,
    String? ctaLabel,
    WeeklyReportToplistHighlight? toplistHighlight,
    String? deltaLabel,
    bool? deltaIncreased,
    double? deltaPercent,
  }) {
    return WeeklyReportEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      score: score ?? this.score,
      generatedAt: generatedAt ?? this.generatedAt,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      toplistHighlight: toplistHighlight ?? this.toplistHighlight,
      deltaLabel: deltaLabel ?? this.deltaLabel,
      deltaIncreased: deltaIncreased ?? this.deltaIncreased,
      deltaPercent: deltaPercent ?? this.deltaPercent,
    );
  }
}

class WeeklyReportPick {
  final WeeklyReportEvent event;
  final DateTime generatedAt;

  WeeklyReportPick(this.event, this.generatedAt);
}

class WeeklyReportContentPayload {
  final String title;
  final String body;
  final Duration backgroundLead;
  final String eventId;

  WeeklyReportContentPayload({
    required this.title,
    required this.body,
    required this.backgroundLead,
    required this.eventId,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'backgroundLeadMs': backgroundLead.inMilliseconds,
        'eventId': eventId,
      };

  static WeeklyReportContentPayload fromEvent(WeeklyReportEvent? event) =>
      WeeklyReportContentPayload(
        // Always use the generic weekly report title for notifications.
        title: weeklyReportTitleKey.i18n,
        body: event?.body ?? weeklyReportBodyKey.i18n,
        backgroundLead: weeklyReportBackgroundLead,
        eventId: event?.id ?? 'none',
      );
}

class WeeklyReportTotals {
  final int allowed;
  final int blocked;

  const WeeklyReportTotals({required this.allowed, required this.blocked});
}

class WeeklyReportTopEntry {
  final String name;
  final bool blocked;
  final int count;
  final int rank;

  const WeeklyReportTopEntry({
    required this.name,
    required this.blocked,
    required this.count,
    required this.rank,
  });
}

class WeeklyReportPeriod {
  final WeeklyReportTotals totals;
  final List<WeeklyReportTopEntry> blockedToplist;
  final List<WeeklyReportTopEntry> allowedToplist;

  WeeklyReportPeriod({
    required this.totals,
    required this.blockedToplist,
    required this.allowedToplist,
  });
}

class WeeklyReportToplistHighlight {
  final String name;
  final bool blocked;
  final int newRank;
  final int? previousRank;

  const WeeklyReportToplistHighlight({
    required this.name,
    required this.blocked,
    required this.newRank,
    this.previousRank,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'blocked': blocked,
      'newRank': newRank,
      'previousRank': previousRank,
    };
  }

  factory WeeklyReportToplistHighlight.fromJson(Map<String, dynamic> json) {
    return WeeklyReportToplistHighlight(
      name: json['name'],
      blocked: json['blocked'],
      newRank: json['newRank'],
      previousRank: json['previousRank'],
    );
  }
}

class WeeklyReportPendingEvent {
  final WeeklyReportEvent event;
  final DateTime pickedAt;

  WeeklyReportPendingEvent({required this.event, required this.pickedAt});

  Map<String, dynamic> toJson() => {
        'event': event.toJson(),
        'pickedAt': pickedAt.toIso8601String(),
      };

  factory WeeklyReportPendingEvent.fromJson(Map<String, dynamic> json) {
    return WeeklyReportPendingEvent(
      event: WeeklyReportEvent.fromJson(Map<String, dynamic>.from(json['event'])),
      pickedAt: DateTime.parse(json['pickedAt']),
    );
  }
}

class WeeklyReportWindow {
  final WeeklyReportPeriod current;
  final WeeklyReportPeriod previous;
  final DateTime anchor;

  WeeklyReportWindow({
    required this.current,
    required this.previous,
    required this.anchor,
  });
}

class WeeklyTotalsSplitResult {
  final WeeklyReportTotals current;
  final WeeklyReportTotals previous;
  final DateTime anchor;

  WeeklyTotalsSplitResult({
    required this.current,
    required this.previous,
    required this.anchor,
  });
}

@visibleForTesting
WeeklyTotalsSplitResult splitWeeklyTotalsFromStats(platform_stats.JsonStatsEndpoint stats) {
  const daysPerWeek = 7;
  const totalDays = daysPerWeek * 2;
  const secondsPerDay = 24 * 60 * 60;

  final allowedByDay = <int, int>{};
  final blockedByDay = <int, int>{};
  final timestamps = <int>{};

  void collect(Map<int, int> target, List<platform_stats.JsonDps> dps) {
    for (final dp in dps) {
      final ts = dp.timestamp;
      final rounded = dp.value.round();
      target[ts] = (target[ts] ?? 0) + rounded;
      timestamps.add(ts);
    }
  }

  for (var metric in stats.stats.metrics) {
    final action = metric.tags.action;
    final isAllowed = action == "fallthrough" || action == "allowed";
    collect(isAllowed ? allowedByDay : blockedByDay, metric.dps);
  }

  if (timestamps.isEmpty) {
    final now = DateTime.now().toUtc();
    final anchor = DateTime.utc(now.year, now.month, now.day);
    return WeeklyTotalsSplitResult(
      current: const WeeklyReportTotals(allowed: 0, blocked: 0),
      previous: const WeeklyReportTotals(allowed: 0, blocked: 0),
      anchor: anchor,
    );
  }

  final latest = timestamps.reduce((a, b) => a > b ? a : b);
  final timeline = <int>[];
  for (int i = totalDays - 1; i >= 0; i--) {
    timeline.add(latest - i * secondsPerDay);
  }

  final previousDays = timeline.sublist(0, daysPerWeek);
  final currentDays = timeline.sublist(daysPerWeek);

  int sumForDays(Map<int, int> source, List<int> days) =>
      days.fold(0, (sum, ts) => sum + (source[ts] ?? 0));

  final currentAllowed = sumForDays(allowedByDay, currentDays);
  final previousAllowed = sumForDays(allowedByDay, previousDays);
  final currentBlocked = sumForDays(blockedByDay, currentDays);
  final previousBlocked = sumForDays(blockedByDay, previousDays);

  final boundaryTimestamp = currentDays.first;
  final anchor = DateTime.fromMillisecondsSinceEpoch(boundaryTimestamp * 1000, isUtc: true);

  return WeeklyTotalsSplitResult(
    current: WeeklyReportTotals(allowed: currentAllowed, blocked: currentBlocked),
    previous: WeeklyReportTotals(allowed: previousAllowed, blocked: previousBlocked),
    anchor: anchor,
  );
}

abstract class WeeklyReportEventSource {
  String get name;

  Future<List<WeeklyReportEvent>> generate(WeeklyReportGenerationContext context, Marker m);
}

class WeeklyReportToplistWindow {
  final List<WeeklyReportTopEntry> currentBlocked;
  final List<WeeklyReportTopEntry> previousBlocked;
  final List<WeeklyReportTopEntry> currentAllowed;
  final List<WeeklyReportTopEntry> previousAllowed;

  WeeklyReportToplistWindow({
    required this.currentBlocked,
    required this.previousBlocked,
    required this.currentAllowed,
    required this.previousAllowed,
  });
}

class WeeklyReportGenerationContext {
  final WeeklyReportRepository _repository;

  WeeklyTotalsSplitResult? _totals;
  bool _totalsLoaded = false;
  WeeklyReportToplistWindow? _toplists;
  bool _toplistsLoaded = false;

  WeeklyReportGenerationContext(this._repository);

  Future<WeeklyTotalsSplitResult?> totals(Marker m) async {
    if (_totalsLoaded) return _totals;
    _totalsLoaded = true;
    _totals = await _repository.loadTotals(m);
    return _totals;
  }

  Future<WeeklyReportToplistWindow?> toplists(Marker m) async {
    if (_toplistsLoaded) return _toplists;
    _toplistsLoaded = true;

    final totalsResult = await totals(m);
    if (totalsResult == null) return null;

    _toplists = await _repository.loadToplists(m, anchor: totalsResult.anchor);
    return _toplists;
  }
}

class WeeklyTotalsDeltaSource implements WeeklyReportEventSource {
  @override
  String get name => 'totals_delta';

  @override
  Future<List<WeeklyReportEvent>> generate(WeeklyReportGenerationContext context, Marker m) async {
    final totalsResult = await context.totals(m);
    if (totalsResult == null) return [];

    final results = <WeeklyReportEvent>[];
    final previousBlocked = totalsResult.previous.blocked;
    final currentBlocked = totalsResult.current.blocked;
    final previousAllowed = totalsResult.previous.allowed;
    final currentAllowed = totalsResult.current.allowed;
    final blockedDelta = _percentChange(previousBlocked, currentBlocked);
    final allowedDelta = _percentChange(previousAllowed, currentAllowed);

    final blockedEvent = _buildEvent(
      totalsResult.anchor,
      label: 'Blocked',
      previous: previousBlocked,
      current: currentBlocked,
      delta: blockedDelta,
      positiveIsIncrease: false,
      key: 'blocked',
    );
    if (blockedEvent != null) {
      results.add(blockedEvent);
    }

    final allowedEvent = _buildEvent(
      totalsResult.anchor,
      label: 'Allowed',
      previous: previousAllowed,
      current: currentAllowed,
      delta: allowedDelta,
      positiveIsIncrease: true,
      key: 'allowed',
    );
    if (allowedEvent != null) {
      results.add(allowedEvent);
    }

    return results;
  }

  WeeklyReportEvent? _buildEvent(
    DateTime anchor, {
    required String label,
    required int previous,
    required int current,
    required double delta,
    required bool positiveIsIncrease,
    required String key,
  }) {
    // Avoid noise on tiny changes
    final absDelta = delta.abs();
    if (absDelta < 1) return null;

    final increased = delta > 0;
    final sign = increased ? '+' : '-';
    final icon =
        increased == positiveIsIncrease ? WeeklyReportIcon.trendUp : WeeklyReportIcon.trendDown;
    final percent = absDelta.toStringAsFixed(absDelta >= 10 ? 0 : 1);
    final multiplier = _multiplierLabel(previous, current);
    final id = 'totals:$key:${anchor.toIso8601String()}';

    final title = _totalsTitle(label, increased);
    final body = _totalsBody(label, increased && multiplier != null ? multiplier : '$sign$percent');

    return WeeklyReportEvent(
      id: id,
      title: title,
      body: body,
      type: WeeklyReportEventType.totalsDelta,
      icon: icon,
      score: absDelta,
      generatedAt: anchor,
      ctaLabel: weeklyReportCtaKey.i18n,
      toplistHighlight: null,
      deltaLabel: key,
      deltaIncreased: increased,
      deltaPercent: absDelta,
    );
  }

  String _totalsTitle(String label, bool increased) {
    if (label == 'Blocked') {
      return increased
          ? weeklyReportBlockedIncreasedTitleKey.i18n
          : weeklyReportBlockedDecreasedTitleKey.i18n;
    }
    return increased
        ? weeklyReportAllowedIncreasedTitleKey.i18n
        : weeklyReportAllowedDecreasedTitleKey.i18n;
  }

  String _totalsBody(String label, String value) {
    if (label == 'Blocked') {
      return weeklyReportBlockedTotalsBodyKey.i18n.withParams(value);
    }
    return weeklyReportAllowedTotalsBodyKey.i18n.withParams(value);
  }

  double _percentChange(int previous, int current) {
    if (previous == 0) {
      if (current == 0) return 0;
      return 100;
    }
    return ((current - previous) / previous) * 100;
  }

  String? _multiplierLabel(int previous, int current) {
    if (previous <= 0 || current <= previous) return null;
    final multiplier = current / previous;
    if (multiplier < 2) return null;
    return '${multiplier.ceil()}x';
  }
}

class ToplistMovementSource implements WeeklyReportEventSource {
  @override
  String get name => 'toplist_movement';

  @override
  Future<List<WeeklyReportEvent>> generate(WeeklyReportGenerationContext context, Marker m) async {
    final totals = await context.totals(m);
    final toplists = await context.toplists(m);
    if (totals == null || toplists == null) return [];

    final events = <WeeklyReportEvent>[];
    events.addAll(_fromToplists(
      current: toplists.currentBlocked,
      previous: toplists.previousBlocked,
      blocked: true,
      anchor: totals.anchor,
    ));
    events.addAll(_fromToplists(
      current: toplists.currentAllowed,
      previous: toplists.previousAllowed,
      blocked: false,
      anchor: totals.anchor,
    ));
    return events;
  }

  List<WeeklyReportEvent> _fromToplists({
    required List<WeeklyReportTopEntry> current,
    required List<WeeklyReportTopEntry> previous,
    required bool blocked,
    required DateTime anchor,
  }) {
    final previousByName = <String, WeeklyReportTopEntry>{};
    for (final entry in previous) {
      previousByName[entry.name.toLowerCase()] = entry;
    }

    final results = <WeeklyReportEvent>[];
    for (final entry in current) {
      final currentRank = entry.rank + 1;
      final prev = previousByName[entry.name.toLowerCase()];
      final prevRank = prev != null ? prev.rank + 1 : null;
      final id =
          'toplist:${blocked ? 'blocked' : 'allowed'}:${entry.name}:${anchor.toIso8601String()}';

      if (prevRank == null) {
        results.add(WeeklyReportEvent(
          id: id,
          title: blocked
              ? weeklyReportBlockedToplistNewTitleKey.i18n
              : weeklyReportAllowedToplistNewTitleKey.i18n,
          body: weeklyReportToplistNewBodyKey.i18n
              .withParams(entry.name, currentRank.toString()),
          type: WeeklyReportEventType.toplistChange,
          icon: blocked ? WeeklyReportIcon.shield : WeeklyReportIcon.chart,
          score: 80 - currentRank * 5,
          generatedAt: anchor,
          ctaLabel: weeklyReportCtaKey.i18n,
          toplistHighlight: WeeklyReportToplistHighlight(
            name: entry.name,
            blocked: blocked,
            newRank: currentRank,
            previousRank: null,
          ),
        ));
        continue;
      }

      if (prevRank > currentRank) {
        final movedBy = prevRank - currentRank;
        results.add(WeeklyReportEvent(
          id: id,
          title: blocked
              ? weeklyReportBlockedToplistUpTitleKey.i18n
              : weeklyReportAllowedToplistUpTitleKey.i18n,
          body: weeklyReportToplistMoveBodyKey.i18n.withParams(
            entry.name,
            currentRank.toString(),
            prevRank.toString(),
          ),
          type: WeeklyReportEventType.toplistChange,
          icon: blocked ? WeeklyReportIcon.shield : WeeklyReportIcon.chart,
          score: (50 + movedBy * 5 - currentRank).toDouble(),
          generatedAt: anchor,
          ctaLabel: weeklyReportCtaKey.i18n,
          toplistHighlight: WeeklyReportToplistHighlight(
            name: entry.name,
            blocked: blocked,
            newRank: currentRank,
            previousRank: prevRank,
          ),
        ));
        continue;
      }

      if (prevRank < currentRank) {
        results.add(WeeklyReportEvent(
          id: id,
          title: blocked
              ? weeklyReportBlockedToplistDownTitleKey.i18n
              : weeklyReportAllowedToplistDownTitleKey.i18n,
          body: weeklyReportToplistMoveBodyKey.i18n.withParams(
            entry.name,
            currentRank.toString(),
            prevRank.toString(),
          ),
          type: WeeklyReportEventType.toplistChange,
          icon: blocked ? WeeklyReportIcon.shield : WeeklyReportIcon.chart,
          score: (30 - currentRank).toDouble(),
          generatedAt: anchor,
          ctaLabel: weeklyReportCtaKey.i18n,
          toplistHighlight: WeeklyReportToplistHighlight(
            name: entry.name,
            blocked: blocked,
            newRank: currentRank,
            previousRank: prevRank,
          ),
        ));
      }
    }

    return results;
  }
}

class WeeklyReportRepository with Logging {
  late final _statsApi = Core.get<platform_stats.StatsApi>();
  late final _deviceStore = Core.get<DeviceStore>();
  late final _toplists = Core.get<ToplistStore>();

  Future<WeeklyTotalsSplitResult?> loadTotals(Marker m) async {
    return await log(m).trace('weeklyReport:loadTotals', (m) async {
      final deviceName = _deviceStore.deviceAlias;
      if (deviceName.isEmpty) {
        log(m).w('deviceAlias not ready, skipping weekly report totals fetch');
        return null;
      }

      try {
        final rollingStats = await _statsApi.getStatsForDevice("2w", "24h", deviceName, m);
        final totalsSplit = splitWeeklyTotalsFromStats(rollingStats);
        log(m)
          ..pair('totalsBlockedCurrent', totalsSplit.current.blocked)
          ..pair('totalsBlockedPrevious', totalsSplit.previous.blocked)
          ..pair('totalsAllowedCurrent', totalsSplit.current.allowed)
          ..pair('totalsAllowedPrevious', totalsSplit.previous.allowed);
        return totalsSplit;
      } catch (e) {
        log(m).e(msg: 'Failed to fetch stats for weekly report totals: $e');
        return null;
      }
    });
  }

  Future<WeeklyReportToplistWindow?> loadToplists(Marker m, {required DateTime anchor}) async {
    return await log(m).trace('weeklyReport:loadToplists', (m) async {
      final deviceName = _deviceStore.deviceAlias;
      if (deviceName.isEmpty) {
        log(m).w('deviceAlias not ready, skipping weekly report toplist fetch');
        return null;
      }

      final previousEndIso = anchor.toIso8601String();
      final currentEndIso = anchor.add(const Duration(days: 7)).toIso8601String();

      final currentBlocked = await _fetchToplist(
        m,
        deviceName: deviceName,
        action: "blocked",
        range: "7d",
        end: currentEndIso,
      );
      final previousBlocked = await _fetchToplist(
        m,
        deviceName: deviceName,
        action: "blocked",
        range: "7d",
        end: previousEndIso,
      );

      final currentAllowed = await _fetchAllowedToplist(
        m,
        deviceName: deviceName,
        range: "7d",
        end: currentEndIso,
      );
      final previousAllowed = await _fetchAllowedToplist(
        m,
        deviceName: deviceName,
        range: "7d",
        end: previousEndIso,
      );

      return WeeklyReportToplistWindow(
        currentBlocked: currentBlocked,
        previousBlocked: previousBlocked,
        currentAllowed: currentAllowed,
        previousAllowed: previousAllowed,
      );
    });
  }

  Future<List<WeeklyReportTopEntry>> _fetchAllowedToplist(
    Marker m, {
    required String deviceName,
    required String range,
    required String? end,
  }) async {
    platform_stats.JsonToplistV2Response? allowed;
    platform_stats.JsonToplistV2Response? fallthrough;
    try {
      allowed = await _toplists.fetch(
        m: m,
        deviceName: deviceName,
        level: 1,
        action: "allowed",
        limit: 5,
        range: range,
        end: end,
        ttl: Duration(seconds: 10),
      );
    } catch (e, s) {
      log(m).w("Failed to fetch allowed toplist: $e");
    }

    try {
      fallthrough = await _toplists.fetch(
        m: m,
        deviceName: deviceName,
        level: 1,
        action: "fallthrough",
        limit: 5,
        range: range,
        end: end,
        ttl: Duration(seconds: 10),
      );
    } catch (e, s) {
      log(m).w("Failed to fetch fallthrough toplist: $e");
    }

    return _mergeAllowedToplists(allowed, fallthrough);
  }

  Future<List<WeeklyReportTopEntry>> _fetchToplist(
    Marker m, {
    required String deviceName,
    required String action,
    required String range,
    required String? end,
  }) async {
    try {
      final response = await _toplists.fetch(
        m: m,
        deviceName: deviceName,
        level: 1,
        action: action,
        limit: 5,
        range: range,
        end: end,
        ttl: Duration(seconds: 10),
      );
      return _convertToplist(response, blocked: action == "blocked");
    } catch (e, s) {
      log(m).w("Failed to fetch toplist for $action: $e");
      return [];
    }
  }

  List<WeeklyReportTopEntry> _mergeAllowedToplists(platform_stats.JsonToplistV2Response? allowed,
      platform_stats.JsonToplistV2Response? fallthrough) {
    final entries = <String, int>{};

    void collect(platform_stats.JsonToplistV2Response? response) {
      if (response == null) return;
      for (var bucket in response.toplist) {
        for (var entry in bucket.entries) {
          entries[entry.name] = (entries[entry.name] ?? 0) + entry.count;
        }
      }
    }

    collect(allowed);
    collect(fallthrough);

    final merged = entries.entries
        .map((e) => WeeklyReportTopEntry(
              name: e.key,
              blocked: false,
              count: e.value,
              rank: 0,
            ))
        .toList();
    merged.sort((a, b) => b.count.compareTo(a.count));
    final limited = merged.take(5).toList();
    for (var i = 0; i < limited.length; i++) {
      limited[i] = WeeklyReportTopEntry(
        name: limited[i].name,
        blocked: false,
        count: limited[i].count,
        rank: i,
      );
    }
    return limited;
  }

  List<WeeklyReportTopEntry> _convertToplist(
    platform_stats.JsonToplistV2Response response, {
    required bool blocked,
  }) {
    final result = <WeeklyReportTopEntry>[];
    for (var bucket in response.toplist) {
      for (var i = 0; i < bucket.entries.length; i++) {
        final entry = bucket.entries[i];
        result.add(WeeklyReportTopEntry(
          name: entry.name,
          blocked: blocked,
          count: entry.count,
          rank: i,
        ));
      }
    }
    result.sort((a, b) => b.count.compareTo(a.count));
    final limited = result.take(5).toList();
    for (var i = 0; i < limited.length; i++) {
      limited[i] = WeeklyReportTopEntry(
        name: limited[i].name,
        blocked: blocked,
        count: limited[i].count,
        rank: i,
      );
    }
    return limited;
  }
}

class WeeklyReportActor with Logging, Actor {
  late final _repository = WeeklyReportRepository();
  late final _lastDismissed = WeeklyReportLastDismissedValue();
  late final _pendingEvent = Core.get<WeeklyReportPendingEventValue>();
  late final _optOut = Core.get<WeeklyReportOptOutValue>();

  final Observable<WeeklyReportEvent?> currentEvent = Observable(null);
  final Observable<bool> hasUnseen = Observable(false);
  final Observable<bool> isLoading = Observable(false);

  late final List<WeeklyReportEventSource> _sources;
  static const bool weeklyReportForceMockEvent = false;

  WeeklyReportActor() {
    _sources = [
      WeeklyTotalsDeltaSource(),
      ToplistMovementSource(),
    ];
  }

  Future<bool> _isOptedOut(Marker m) async {
    try {
      final cached = _optOut.present;
      if (cached != null) return cached;
      return await _optOut.fetch(m);
    } catch (_) {
      return false;
    }
  }

  void _setCurrent(WeeklyReportEvent? event, {DateTime? pickedAt}) {
    runInAction(() {
      currentEvent.value = event;
      hasUnseen.value = event != null;
    });
  }

  void _setLoading(bool value) {
    runInAction(() {
      isLoading.value = value;
    });
  }

  Future<bool> _hydratePendingEvent(Marker m) async {
    if (currentEvent.value != null) return true;
    final pending = await _pendingEvent.fetch(m);
    if (pending == null) return false;
    _setCurrent(pending.event, pickedAt: pending.pickedAt);
    return true;
  }

  @override
  onStart(Marker m) async {
    // Weekly report generation is now triggered explicitly from the Privacy Pulse screen.
    if (Core.act.isFamily) return;
  }

  Future<WeeklyReportEvent?> refreshAndPick(Marker m) async {
    if (!weeklyReportGenerationEnabled) {
      log(m).t('weeklyReport:disabled:generate');
      _setCurrent(null);
      await _pendingEvent.change(m, null);
      return null;
    }

    final optOut = await _isOptedOut(m);
    if (optOut) {
      log(m).t('weeklyReport:optOut');
      _setCurrent(null);
      await _pendingEvent.change(m, null);
      return null;
    }

    await _hydratePendingEvent(m);
    _setLoading(true);
    final pick = await _generatePick(m);
    _setCurrent(pick?.event);
    _setLoading(false);
    final logger = log(m);
    if (pick?.event != null) {
      logger
        ..t('weeklyReport:eventGenerated')
        ..pair('eventId', pick!.event.id)
        ..pair('title', pick.event.title)
        ..pair('type', pick.event.type.name)
        ..pair('score', pick.event.score)
        ..pair('generatedAt', pick.generatedAt.toIso8601String());
    } else {
      logger.t('weeklyReport:noEvent');
    }
    return pick?.event;
  }

  Future<WeeklyReportEvent?> refreshAndPickForNotification(Marker m) async {
    return await log(m).trace('weeklyReport:notificationGenerate', (m) async {
      final optOut = await _isOptedOut(m);
      if (optOut) {
        log(m).t('weeklyReport:optOut:notification');
        await _pendingEvent.change(m, null);
        return null;
      }
      await _hydratePendingEvent(m);
      _setLoading(true);
      final pick = await _generatePick(m);
      _setCurrent(pick?.event);
      _setLoading(false);
      final logger = log(m);
      if (pick?.event != null) {
        logger
          ..t('weeklyReport:eventGenerated')
          ..pair('eventId', pick!.event.id)
          ..pair('title', pick.event.title)
          ..pair('type', pick.event.type.name)
          ..pair('score', pick.event.score)
          ..pair('generatedAt', pick.generatedAt.toIso8601String());
      } else {
        logger.t('weeklyReport:noEvent');
      }
      return pick?.event;
    });
  }

  Future<void> dismissCurrent(Marker m) async {
    final event = currentEvent.value;
    if (event == null) return;
    log(m)
      ..t('weeklyReport:dismissCurrent')
      ..pair('eventId', event.id);
    await _lastDismissed.change(m, event.id);
    _setCurrent(null);
    await _pendingEvent.change(m, null);
  }

  Future<WeeklyReportPick?> _generatePick(Marker m) async {
    final pending = await _pendingEvent.fetch(m);
    if (pending != null) {
      log(m).t('weeklyReport:reusePending');
      return WeeklyReportPick(pending.event, pending.pickedAt);
    }
    final optOut = await _isOptedOut(m);
    if (optOut) {
      log(m).t('weeklyReport:optOut:skipGenerate');
      await _pendingEvent.change(m, null);
      return null;
    }

    final context = WeeklyReportGenerationContext(_repository);
    final dismissed = await _lastDismissed.fetch(m);
    WeeklyReportEvent? picked;
    int skippedDismissed = 0;

    for (final source in _sources) {
      try {
        final generated = await source.generate(context, m);
        if (generated.isEmpty) continue;

        generated.sort((a, b) => b.score.compareTo(a.score));
        final filtered = generated.where((event) => dismissed == null || event.id != dismissed);
        final candidate = filtered.firstOrNull;
        skippedDismissed += generated.length - filtered.length;

        if (candidate != null) {
          picked = candidate;
          break;
        }
      } catch (e, s) {
        log(m).w('WeeklyReport source ${source.name} failed: $e');
      }
    }

    if (picked == null) {
      if (skippedDismissed > 0) {
        log(m).t('weeklyReport:filteredSeenOrDismissed');
      } else {
        log(m).i('No weekly report event to show');
      }
      return weeklyReportForceMockEvent ? _buildMockPick() : null;
    }

    if (skippedDismissed > 0) {
      final logger = log(m)..t('weeklyReport:filteredSeenOrDismissed');
      logger
        ..pair('skipped', skippedDismissed)
        ..pair('remainingTop', picked.id);
    }

    // Use the pick time for UI freshness while keeping the anchor in IDs.
    final pickedAt = DateTime.now().toUtc();
    final pickedEvent = picked.copyWith(generatedAt: pickedAt);
    return WeeklyReportPick(pickedEvent, pickedAt);
  }

  WeeklyReportPick _buildMockPick() {
    final now = DateTime.now().toUtc();
    final title = weeklyReportBlockedToplistNewTitleKey.i18n;
    final body =
        weeklyReportToplistNewBodyKey.i18n.withParams('tracker.example', '2');
    final event = WeeklyReportEvent(
      id: 'mock:${now.toIso8601String()}',
      title: title,
      body: body,
      type: WeeklyReportEventType.toplistChange,
      icon: WeeklyReportIcon.shield,
      score: 80,
      generatedAt: now,
      ctaLabel: weeklyReportCtaKey.i18n,
      toplistHighlight: WeeklyReportToplistHighlight(
        name: 'tracker.example',
        blocked: true,
        newRank: 2,
        previousRank: null,
      ),
      deltaLabel: null,
      deltaIncreased: null,
      deltaPercent: null,
    );
    return WeeklyReportPick(event, now);
  }

}
