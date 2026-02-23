import 'dart:convert';

import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stats/api.dart' as stats_api;
import 'package:common/src/platform/stats/toplist_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';
import '../../../platform/perm/actor_test.mocks.dart';

class _CountingApi extends Api {
  _CountingApi(this.responseBody);

  final String responseBody;
  final List<ApiEndpoint> calls = [];
  final List<Map<ApiParam, String?>> paramsLog = [];

  @override
  Future<JsonString> get(
    ApiEndpoint endpoint,
    Marker m, {
    QueryParams? params,
  }) async {
    calls.add(endpoint);
    paramsLog.add(params ?? {});
    if (endpoint != ApiEndpoint.getStatsV2) {
      throw StateError('Unexpected endpoint call: $endpoint');
    }
    return responseBody;
  }
}

class _ToplistCall {
  final String action;
  final String range;
  final String? end;

  _ToplistCall({
    required this.action,
    required this.range,
    required this.end,
  });
}

class _CountingToplistStore extends ToplistStore {
  final List<_ToplistCall> calls = [];
  int _blockedCallCount = 0;

  @override
  Future<stats_api.JsonToplistV2Response> fetch({
    required Marker m,
    String? deviceTag,
    String? deviceName,
    int level = 1,
    String? action,
    String? domain,
    int limit = 10,
    String range = "24h",
    String? end,
    String? date,
    Duration ttl = ToplistStore.defaultTtl,
    bool force = false,
  }) async {
    final resolvedAction = action ?? '';
    calls.add(_ToplistCall(action: resolvedAction, range: range, end: end));

    if (resolvedAction == 'blocked') {
      _blockedCallCount++;
      if (_blockedCallCount == 1) {
        return _toplistResponse(
          action: 'blocked',
          entries: [
            stats_api.JsonToplistEntry(name: 'tracker.example', count: 120),
          ],
        );
      }
      return _toplistResponse(action: 'blocked', entries: const []);
    }

    return _toplistResponse(action: resolvedAction, entries: const []);
  }
}

stats_api.JsonToplistV2Response _toplistResponse({
  required String action,
  required List<stats_api.JsonToplistEntry> entries,
}) {
  return stats_api.JsonToplistV2Response(
    toplist: [
      stats_api.JsonToplistBucket(action: action, entries: entries),
    ],
    window: stats_api.JsonWindow(
      label: '7d',
      start: '2025-01-01T00:00:00Z',
      end: '2025-01-08T00:00:00Z',
    ),
    level: '1',
    limit: 5,
  );
}

void main() {
  group('WeeklyReportActor notification request budget', () {
    test('falls back to weekly toplists when totals do not trigger an event', () async {
      await withTrace((m) async {
        await CoreModule().create();
        final api = _CountingApi(_buildRolling2wStatsJson(
          previousAllowedPerDay: 10,
          currentAllowedPerDay: 10,
          previousBlockedPerDay: 20,
          currentBlockedPerDay: 20,
        ));
        Core.register<Api>(api);
        Core.register<stats_api.StatsApi>(stats_api.StatsApi());
        final toplists = _CountingToplistStore();
        Core.register<ToplistStore>(toplists);

        final device = MockDeviceStore();
        when(device.deviceAlias).thenReturn('device-1');
        Core.register<DeviceStore>(device);

        Core.register<WeeklyReportPendingEventValue>(WeeklyReportPendingEventValue());
        Core.register<WeeklyReportOptOutValue>(WeeklyReportOptOutValue());

        final actor = WeeklyReportActor();
        final event = await actor.refreshAndPickForNotification(m);

        expect(event, isNotNull);
        expect(event!.type, equals(WeeklyReportEventType.toplistChange));
        expect(api.calls, equals([ApiEndpoint.getStatsV2]));
        expect(api.paramsLog.single[ApiParam.statsSince], equals('2w'));
        expect(api.paramsLog.single[ApiParam.statsDownsample], equals('24h'));
        expect(api.paramsLog.single.containsKey(ApiParam.toplistRange), isFalse);
        expect(toplists.calls.length, equals(6));
        expect(toplists.calls.every((c) => c.range == '7d'), isTrue);
        expect(toplists.calls.any((c) => c.range == '24h'), isFalse);
      });
    });

    test('uses weekly totals request only when totals event is triggered', () async {
      await withTrace((m) async {
        await CoreModule().create();
        final api = _CountingApi(_buildRolling2wStatsJson(
          previousAllowedPerDay: 10,
          currentAllowedPerDay: 40,
          previousBlockedPerDay: 20,
          currentBlockedPerDay: 20,
        ));
        Core.register<Api>(api);
        Core.register<stats_api.StatsApi>(stats_api.StatsApi());
        final toplists = _CountingToplistStore();
        Core.register<ToplistStore>(toplists);

        final device = MockDeviceStore();
        when(device.deviceAlias).thenReturn('device-1');
        Core.register<DeviceStore>(device);

        Core.register<WeeklyReportPendingEventValue>(WeeklyReportPendingEventValue());
        Core.register<WeeklyReportOptOutValue>(WeeklyReportOptOutValue());

        final actor = WeeklyReportActor();
        final event = await actor.refreshAndPickForNotification(m);

        expect(event, isNotNull);
        expect(event!.type, equals(WeeklyReportEventType.totalsDelta));
        expect(api.calls, equals([ApiEndpoint.getStatsV2]));
        expect(api.paramsLog.single[ApiParam.statsSince], equals('2w'));
        expect(api.paramsLog.single[ApiParam.statsDownsample], equals('24h'));
        expect(api.paramsLog.single.containsKey(ApiParam.toplistRange), isFalse);
        expect(toplists.calls, isEmpty);
      });
    });

    test('does not generate weekly events without full 14-day comparison', () async {
      await withTrace((m) async {
        await CoreModule().create();
        final api = _CountingApi(_buildRollingStatsJson(
          days: 8,
          previousAllowedPerDay: 10,
          currentAllowedPerDay: 40,
          previousBlockedPerDay: 20,
          currentBlockedPerDay: 20,
        ));
        Core.register<Api>(api);
        Core.register<stats_api.StatsApi>(stats_api.StatsApi());
        final toplists = _CountingToplistStore();
        Core.register<ToplistStore>(toplists);

        final device = MockDeviceStore();
        when(device.deviceAlias).thenReturn('device-1');
        Core.register<DeviceStore>(device);

        Core.register<WeeklyReportPendingEventValue>(WeeklyReportPendingEventValue());
        Core.register<WeeklyReportOptOutValue>(WeeklyReportOptOutValue());

        final actor = WeeklyReportActor();
        final event = await actor.refreshAndPickForNotification(m);

        expect(event, isNull);
        expect(api.calls, equals([ApiEndpoint.getStatsV2]));
        expect(toplists.calls, isEmpty);
      });
    });
  });
}

String _buildRolling2wStatsJson({
  required int previousAllowedPerDay,
  required int currentAllowedPerDay,
  required int previousBlockedPerDay,
  required int currentBlockedPerDay,
}) {
  return _buildRollingStatsJson(
    days: 14,
    previousAllowedPerDay: previousAllowedPerDay,
    currentAllowedPerDay: currentAllowedPerDay,
    previousBlockedPerDay: previousBlockedPerDay,
    currentBlockedPerDay: currentBlockedPerDay,
  );
}

String _buildRollingStatsJson({
  required int days,
  required int previousAllowedPerDay,
  required int currentAllowedPerDay,
  required int previousBlockedPerDay,
  required int currentBlockedPerDay,
}) {
  const secondsPerDay = 24 * 60 * 60;
  const startTimestamp = 1736899200; // 2025-01-15T00:00:00Z
  final allowedDps = <Map<String, dynamic>>[];
  final blockedDps = <Map<String, dynamic>>[];
  final currentWindowStart = (days - 7).clamp(0, days);

  for (var i = 0; i < days; i++) {
    final ts = startTimestamp + (i * secondsPerDay);
    final isCurrentWindow = i >= currentWindowStart;
    allowedDps.add({
      'timestamp': '$ts',
      'value': isCurrentWindow ? currentAllowedPerDay : previousAllowedPerDay,
    });
    blockedDps.add({
      'timestamp': '$ts',
      'value': isCurrentWindow ? currentBlockedPerDay : previousBlockedPerDay,
    });
  }

  return jsonEncode({
    'total_allowed': '0',
    'total_blocked': '0',
    'stats': {
      'metrics': [
        {
          'tags': {'action': 'allowed'},
          'dps': allowedDps,
        },
        {
          'tags': {'action': 'blocked'},
          'dps': blockedDps,
        },
      ],
    },
  });
}
