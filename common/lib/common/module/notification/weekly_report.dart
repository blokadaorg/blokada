part of 'notification.dart';

const Duration weeklyReportInterval = Duration(minutes: 10);
const Duration weeklyReportFreshnessWindow = Duration(minutes: 20);
const Duration weeklyReportBackgroundLead = Duration(minutes: 2);

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
  final String? timeLabel;
  final WeeklyReportToplistHighlight? toplistHighlight;

  WeeklyReportEvent({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.icon,
    required this.score,
    required this.generatedAt,
    this.ctaLabel,
    this.timeLabel,
    this.toplistHighlight,
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
      'timeLabel': timeLabel,
      'toplistHighlight': toplistHighlight?.toJson(),
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
      timeLabel: json['timeLabel'],
      toplistHighlight: json['toplistHighlight'] != null
          ? WeeklyReportToplistHighlight.fromJson(
              Map<String, dynamic>.from(json['toplistHighlight']))
          : null,
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
        title: event?.title ?? 'Weekly privacy report',
        body: event?.body ?? 'See this week\'s highlights from your protection.',
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

  Future<List<WeeklyReportEvent>> generate(WeeklyReportWindow window, Marker m);
}

class WeeklyTotalsDeltaSource implements WeeklyReportEventSource {
  @override
  String get name => 'totals_delta';

  @override
  Future<List<WeeklyReportEvent>> generate(WeeklyReportWindow window, Marker m) async {
    final results = <WeeklyReportEvent>[];
    final blockedDelta =
        _percentChange(window.previous.totals.blocked, window.current.totals.blocked);
    final allowedDelta =
        _percentChange(window.previous.totals.allowed, window.current.totals.allowed);

    final blockedEvent = _buildEvent(
      window,
      label: 'Blocked',
      delta: blockedDelta,
      positiveIsIncrease: false,
      key: 'blocked',
    );
    if (blockedEvent != null) {
      results.add(blockedEvent);
    }

    final allowedEvent = _buildEvent(
      window,
      label: 'Allowed',
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
    WeeklyReportWindow window, {
    required String label,
    required double delta,
    required bool positiveIsIncrease,
    required String key,
  }) {
    // Avoid noise on tiny changes
    final absDelta = delta.abs();
    if (absDelta < 1) return null;

    final increased = delta > 0;
    final direction = increased ? 'increased' : 'decreased';
    final sign = increased ? '+' : '-';
    final icon =
        increased == positiveIsIncrease ? WeeklyReportIcon.trendUp : WeeklyReportIcon.trendDown;
    final percent = absDelta.toStringAsFixed(absDelta >= 10 ? 0 : 1);
    final id = 'totals:$key:${window.anchor.toIso8601String()}';

    final title = '$label $direction';
    final body = '$label traffic is $sign$percent% compared to last week.';

    return WeeklyReportEvent(
      id: id,
      title: title,
      body: body,
      type: WeeklyReportEventType.totalsDelta,
      icon: icon,
      score: absDelta,
      generatedAt: window.anchor,
      ctaLabel: 'View report',
      timeLabel: 'This week',
      toplistHighlight: null,
    );
  }

  double _percentChange(int previous, int current) {
    if (previous == 0) {
      if (current == 0) return 0;
      return 100;
    }
    return ((current - previous) / previous) * 100;
  }
}

class ToplistMovementSource implements WeeklyReportEventSource {
  @override
  String get name => 'toplist_movement';

  @override
  Future<List<WeeklyReportEvent>> generate(WeeklyReportWindow window, Marker m) async {
    final events = <WeeklyReportEvent>[];
    events.addAll(_compare(window, blocked: true));
    events.addAll(_compare(window, blocked: false));
    return events;
  }

  List<WeeklyReportEvent> _compare(WeeklyReportWindow window, {required bool blocked}) {
    final current = blocked ? window.current.blockedToplist : window.current.allowedToplist;
    final previous = blocked ? window.previous.blockedToplist : window.previous.allowedToplist;
    final previousMap = {
      for (var entry in previous) entry.name.toLowerCase(): entry.rank,
    };

    final results = <WeeklyReportEvent>[];
    for (final entry in current) {
      final normalized = entry.name.toLowerCase();
      final prevRank = previousMap[normalized];
      final currentRank = entry.rank + 1; // user-facing rank
      if (prevRank == null) {
        final id =
            'toplist:${blocked ? 'blocked' : 'allowed'}:${entry.name}:${window.anchor.toIso8601String()}';
        results.add(WeeklyReportEvent(
          id: id,
          title: blocked ? 'New tracker in top list' : 'New domain in top list',
          body: '${entry.name} is now #$currentRank this week.',
          type: WeeklyReportEventType.toplistChange,
          icon: blocked ? WeeklyReportIcon.shield : WeeklyReportIcon.chart,
          score: 80 - entry.rank * 5,
          generatedAt: window.anchor,
          ctaLabel: 'View report',
          timeLabel: 'This week',
          toplistHighlight: WeeklyReportToplistHighlight(
            name: entry.name,
            blocked: blocked,
            newRank: currentRank,
            previousRank: null,
          ),
        ));
      } else if (prevRank > entry.rank) {
        final movedBy = prevRank - entry.rank;
        final id =
            'toplist:${blocked ? 'blocked' : 'allowed'}:${entry.name}:${window.anchor.toIso8601String()}';
        results.add(WeeklyReportEvent(
          id: id,
          title: blocked ? 'Tracker activity increased' : 'Domain moved up',
          body: '${entry.name} moved to #$currentRank (was #${prevRank + 1}) this week.',
          type: WeeklyReportEventType.toplistChange,
          icon: blocked ? WeeklyReportIcon.shield : WeeklyReportIcon.chart,
          score: (50 + movedBy * 5 - entry.rank).toDouble(),
          generatedAt: window.anchor,
          ctaLabel: 'View report',
          timeLabel: 'This week',
          toplistHighlight: WeeklyReportToplistHighlight(
            name: entry.name,
            blocked: blocked,
            newRank: currentRank,
            previousRank: prevRank + 1,
          ),
        ));
      }
    }

    return results;
  }
}

class WeeklyReportRepository with Logging {
  late final _statsApi = Core.get<platform_stats.StatsApi>();
  late final _accountId = Core.get<AccountId>();
  late final _deviceStore = Core.get<DeviceStore>();

  Future<WeeklyReportWindow?> load(Marker m) async {
    return await log(m).trace('weeklyReport:load', (m) async {
      final deviceName = _deviceStore.deviceAlias;
      if (deviceName.isEmpty) {
        log(m).w('deviceAlias not ready, skipping weekly report fetch');
        return null;
      }

      final platform_stats.JsonStatsEndpoint rollingStats;
      try {
        rollingStats = await _statsApi.getStatsForDevice("2w", "24h", deviceName, m);
      } catch (e) {
        log(m).e(msg: 'Failed to fetch stats for weekly report: $e');
        return null;
      }

      final totalsSplit = splitWeeklyTotalsFromStats(rollingStats);
      final currentTotals = totalsSplit.current;
      final previousTotals = totalsSplit.previous;
      final normalizedAnchor = totalsSplit.anchor;
      final previousEndIso = totalsSplit.anchor.toIso8601String();
      final currentEndIso =
          totalsSplit.anchor.add(const Duration(days: 7)).toIso8601String();

      final accountId = await _accountId.fetch(m);
      final currentBlocked = await _fetchToplist(
        m,
        accountId: accountId,
        deviceName: deviceName,
        action: "blocked",
        range: "7d",
        end: currentEndIso,
      );
      final previousBlocked = await _fetchToplist(
        m,
        accountId: accountId,
        deviceName: deviceName,
        action: "blocked",
        range: "7d",
        end: previousEndIso,
      );

      final currentAllowed = await _fetchAllowedToplist(
        m,
        accountId: accountId,
        deviceName: deviceName,
        range: "7d",
        end: currentEndIso,
      );
      final previousAllowed = await _fetchAllowedToplist(
        m,
        accountId: accountId,
        deviceName: deviceName,
        range: "7d",
        end: previousEndIso,
      );

      final window = WeeklyReportWindow(
        current: WeeklyReportPeriod(
          totals: currentTotals,
          blockedToplist: currentBlocked,
          allowedToplist: currentAllowed,
        ),
        previous: WeeklyReportPeriod(
          totals: previousTotals,
          blockedToplist: previousBlocked,
          allowedToplist: previousAllowed,
        ),
        anchor: normalizedAnchor,
      );

      log(m)
        ..pair('totalsBlockedCurrent', currentTotals.blocked)
        ..pair('totalsBlockedPrevious', previousTotals.blocked)
        ..pair('totalsAllowedCurrent', currentTotals.allowed)
        ..pair('totalsAllowedPrevious', previousTotals.allowed);

      return window;
    });
  }

  Future<List<WeeklyReportTopEntry>> _fetchAllowedToplist(
    Marker m, {
    required String accountId,
    required String deviceName,
    required String range,
    required String? end,
  }) async {
    platform_stats.JsonToplistV2Response? allowed;
    platform_stats.JsonToplistV2Response? fallthrough;
    try {
      allowed = await _statsApi.getToplistV2(
        accountId: accountId,
        deviceName: deviceName,
        level: 1,
        action: "allowed",
        limit: 5,
        range: range,
        end: end,
        m: m,
      );
    } catch (e, s) {
      log(m).w("Failed to fetch allowed toplist: $e");
    }

    try {
      fallthrough = await _statsApi.getToplistV2(
        accountId: accountId,
        deviceName: deviceName,
        level: 1,
        action: "fallthrough",
        limit: 5,
        range: range,
        end: end,
        m: m,
      );
    } catch (e, s) {
      log(m).w("Failed to fetch fallthrough toplist: $e");
    }

    return _mergeAllowedToplists(allowed, fallthrough);
  }

  Future<List<WeeklyReportTopEntry>> _fetchToplist(
    Marker m, {
    required String accountId,
    required String deviceName,
    required String action,
    required String range,
    required String? end,
  }) async {
    try {
      final response = await _statsApi.getToplistV2(
        accountId: accountId,
        deviceName: deviceName,
        level: 1,
        action: action,
        limit: 5,
        range: range,
        end: end,
        m: m,
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
  late final _stage = Core.get<StageStore>();
  late final _notification = Core.get<NotificationActor>();
  late final _scheduledAt = Core.get<WeeklyReportScheduleValue>();
  late final _repository = WeeklyReportRepository();
  late final _lastDismissed = WeeklyReportLastDismissedValue();
  late final _lastScheduled = WeeklyReportLastScheduledValue();
  late final _deviceStore = Core.get<DeviceStore>();
  late final _pendingEvent = Core.get<WeeklyReportPendingEventValue>();

  final Observable<WeeklyReportEvent?> currentEvent = Observable(null);
  final Observable<bool> hasUnseen = Observable(false);
  final Observable<bool> isLoading = Observable(false);

  DateTime? _currentPickedAt;

  late final List<WeeklyReportEventSource> _sources;

  WeeklyReportActor() {
    _sources = [
      WeeklyTotalsDeltaSource(),
      ToplistMovementSource(),
    ];
  }

  bool _initialized = false;
  mobx.ReactionDisposer? _aliasDisposer;

  void _setCurrent(WeeklyReportEvent? event, {DateTime? pickedAt}) {
    runInAction(() {
      currentEvent.value = event;
      hasUnseen.value = event != null;
      _currentPickedAt = event != null ? (pickedAt ?? DateTime.now().toUtc()) : null;
    });
  }

  void _setLoading(bool value) {
    runInAction(() {
      isLoading.value = value;
    });
  }

  bool _hasFreshUnseen() {
    final event = currentEvent.value;
    if (event == null) return false;
    final pickedAt = _currentPickedAt;
    if (pickedAt == null) return false;

    // Use the configured freshness window to avoid overlapping events.
    final age = DateTime.now().toUtc().difference(pickedAt);
    return age < weeklyReportFreshnessWindow;
  }

  Future<WeeklyReportPendingEvent?> _getFreshPendingEvent(Marker m) async {
    final pending = await _pendingEvent.fetch(m);
    if (pending == null) return null;
    final age = DateTime.now().toUtc().difference(pending.pickedAt);
    if (age >= weeklyReportFreshnessWindow) {
      await _pendingEvent.change(m, null);
      return null;
    }
    return pending;
  }

  Future<bool> _hydratePendingEvent(Marker m) async {
    if (currentEvent.value != null) return true;
    final pending = await _getFreshPendingEvent(m);
    if (pending == null) return false;
    _setCurrent(pending.event, pickedAt: pending.pickedAt);
    return true;
  }

  Future<void> _storePendingEvent(Marker m, WeeklyReportEvent? event) async {
    if (event == null) {
      await _pendingEvent.change(m, null);
      return;
    }
    final existing = await _pendingEvent.fetch(m);
    if (existing != null && existing.event.id == event.id) {
      return;
    }
    final pending = WeeklyReportPendingEvent(
      event: event,
      pickedAt: DateTime.now().toUtc(),
    );
    await _pendingEvent.change(m, pending);
  }

  @override
  onStart(Marker m) async {
    if (Core.act.isFamily) return;
    _stage.addOnValue(routeChanged, _onRouteChanged);
    _aliasDisposer = autorun((_) {
      final alias = _deviceStore.deviceAlias;
      if (alias.isEmpty || _initialized) return;
      _initialized = true;
      _refreshAndSchedule(Markers.stats);
    });
  }

  Future<void> _onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isBecameForeground()) return;
    if (!_initialized) return;
    await _refreshAndSchedule(m);
  }

  Future<void> _refreshAndSchedule(Marker m) async {
    await _hydratePendingEvent(m);
    if (_hasFreshUnseen()) {
      log(m).t('weeklyReport:skipRefresh:hasUnseenFresh');
      return;
    }
    final event = await refreshAndPick(m);
    await _ensureScheduled(m, eventOverride: event);
  }

  Future<WeeklyReportEvent?> refreshAndPick(Marker m) async {
    await _hydratePendingEvent(m);
    if (_hasFreshUnseen()) {
      log(m).t('weeklyReport:skipPick:hasUnseenFresh');
      return currentEvent.value;
    }
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

  Future<void> dismissCurrent(Marker m) async {
    final event = currentEvent.value;
    if (event == null) return;
    await _lastDismissed.change(m, event.id);
    _setCurrent(null);
    await _pendingEvent.change(m, null);
  }

  Future<WeeklyReportPick?> _generatePick(Marker m) async {
    final pending = await _getFreshPendingEvent(m);
    if (pending != null) {
      log(m).t('weeklyReport:reusePending');
      return WeeklyReportPick(pending.event, pending.pickedAt);
    }
    WeeklyReportWindow? window = await _repository.load(m);
    if (window == null) return null;

    final events = <WeeklyReportEvent>[];
    for (final source in _sources) {
      try {
        final generated = await source.generate(window, m);
        events.addAll(generated);
      } catch (e, s) {
        log(m).w('WeeklyReport source ${source.name} failed: $e');
      }
    }

    if (events.isEmpty) return null;
    events.sort((a, b) => b.score.compareTo(a.score));
    final dismissed = await _lastDismissed.fetch(m);

    final filtered = events.where((event) {
      if (dismissed != null && event.id == dismissed) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      log(m).i('No weekly report event to show (seen or dismissed already)');
      return null;
    }

    if (filtered.length != events.length) {
      final logger = log(m)..t('weeklyReport:filteredSeenOrDismissed');
      logger
        ..pair('skipped', events.length - filtered.length)
        ..pair('remainingTop', filtered.first.id);
    }

    return WeeklyReportPick(filtered.first, window.anchor);
  }

  Future<void> _ensureScheduled(Marker m, {WeeklyReportEvent? eventOverride}) async {
    await log(m).trace('weeklyReport:onAppOpen', (m) async {
      final now = DateTime.now();
      final stored = await _scheduledAt.fetch(m);
      final target = _pickTarget(now, stored);
      WeeklyReportEvent? event = eventOverride;
      if (event == null) {
        final pick = await _generatePick(m);
        event = pick?.event;
      }
      final payload = WeeklyReportContentPayload.fromEvent(event);

      log(m)
        ..pair('storedAt', stored?.toIso8601String())
        ..pair('scheduledAt', target.toIso8601String())
        ..pair('hasEvent', event != null);

      final scheduleKey = '${payload.eventId}:${target.toIso8601String()}';
      final lastScheduled = await _lastScheduled.fetch(m);
      if (lastScheduled == scheduleKey) {
        log(m).t('weeklyReport:notificationSkipped');
        return;
      }

      await _scheduledAt.change(m, target);
      await _storePendingEvent(m, event);
      await _logBackgroundSchedule(m, target, payload);
      await _notification.showWithBody(
        NotificationId.weeklyReport,
        m,
        jsonEncode(payload.toJson()),
        when: target,
      );
      await _lastScheduled.change(m, scheduleKey);
    });
  }

  Future<void> _logBackgroundSchedule(
    Marker m,
    DateTime target,
    WeeklyReportContentPayload payload,
  ) async {
    final backgroundAt = target.subtract(payload.backgroundLead);
    log(m)
      ..pair('backgroundLeadMs', payload.backgroundLead.inMilliseconds)
      ..pair('backgroundAt', backgroundAt.toIso8601String());
  }

  DateTime _pickTarget(DateTime now, DateTime? stored) {
    if (stored == null) return now.add(weeklyReportInterval);
    if (stored.isAfter(now)) return stored;
    return now.add(weeklyReportInterval);
  }
}
