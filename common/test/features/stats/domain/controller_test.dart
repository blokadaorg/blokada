import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stats/delta_store.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools.dart';

UiStats _uiStats({int allowed = 30, int blocked = 12, List<UiToplistEntry> toplist = const []}) {
  return UiStats(
    totalAllowed: 1000,
    totalBlocked: 400,
    allowedHistogram: [allowed],
    blockedHistogram: [blocked],
    toplist: toplist,
    avgDayTotal: 50,
    avgDayAllowed: 35,
    avgDayBlocked: 15,
    latestTimestamp: 0,
  );
}

final _toplist = [
  UiToplistEntry(null, 'doubleclick.net', true, 14),
  UiToplistEntry(null, 'apple.com', false, 22),
];

/// Serves canned stats and records what was fetched.
class _FakeStatsStore extends Fake implements StatsStore {
  @override
  UiStats stats = UiStats.empty();

  @override
  bool hasStats = false;

  UiStats next = _uiStats();
  List<UiToplistEntry> nextToplist = _toplist;
  StatsCounters weekCounters = const StatsCounters(allowed: 200, blocked: 90, total: 290);
  Object? failDay;
  Object? failToplists;

  final calls = <String>[];

  @override
  Future<UiStats> fetchDay(Marker m, {bool force = false}) async {
    calls.add('day force=$force');
    if (failDay != null) throw failDay!;
    stats = next;
    hasStats = true;
    return stats;
  }

  @override
  Future<UiStats> fetchWeek(Marker m, {bool force = false}) async {
    calls.add('week force=$force');
    if (failDay != null) throw failDay!;
    return stats;
  }

  @override
  Future<StatsCounters> countersForRange(String range, Marker m, {bool force = false}) async {
    calls.add('counters $range force=$force');
    return weekCounters;
  }

  @override
  Future<DailySeries> allowedDailySeries(Marker m, {int days = 7, bool force = false}) async {
    calls.add('series');
    return DailySeries(
      values: const [1, 2, 3],
      end: DateTime.utc(2026),
      step: const Duration(days: 1),
    );
  }

  @override
  Future<void> fetchToplists(Marker m, {String range = "24h"}) async {
    calls.add('toplists $range');
    if (failToplists != null) throw failToplists!;
    stats = UiStats(
      totalAllowed: stats.totalAllowed,
      totalBlocked: stats.totalBlocked,
      allowedHistogram: stats.allowedHistogram.isEmpty ? [0] : stats.allowedHistogram,
      blockedHistogram: stats.blockedHistogram.isEmpty ? [0] : stats.blockedHistogram,
      toplist: nextToplist,
      avgDayAllowed: stats.avgDayAllowed,
      avgDayBlocked: stats.avgDayBlocked,
      avgDayTotal: stats.avgDayTotal,
      latestTimestamp: stats.latestTimestamp,
    );
  }
}

class _FakeDeltaStore extends Fake implements StatsDeltaStore {
  @override
  Future<void> refresh(
    Marker m, {
    required String deviceName,
    required String range,
    bool force = false,
  }) async {}

  @override
  List<ToplistDelta> deltasFor(String deviceName, String range, {required bool blocked}) => [];

  @override
  CounterDelta counterDeltaFor(String deviceName, String range) => CounterDelta.empty();
}

class _FakeDeviceStore extends Fake implements DeviceStore {
  final _listeners = <Function(Marker)>[];

  @override
  String deviceAlias = 'Pixel';

  @override
  addOn<T>(EmitterEvent<T> on, Function(Marker) listener) {
    _listeners.add(listener);
  }

  Future<void> changed() async {
    for (final l in _listeners) {
      await l(Markers.testing);
    }
  }
}

class _FakeJournal extends Fake implements JournalActor {
  List<UiJournalEntry> blocked = [_entry('doubleclick.net', UiJournalAction.block)];
  List<UiJournalEntry> allowed = [_entry('apple.com', UiJournalAction.allow)];
  Object? fail;
  int previews = 0;
  int fetches = 0;

  @override
  Future<List<UiJournalEntry>> fetchPreview(
    Marker m, {
    required UiJournalAction action,
    DeviceTag? tag,
    String? deviceName,
    int limit = 5,
    String? domain,
    bool exactMatchDomain = false,
  }) async {
    previews++;
    if (fail != null) throw fail!;
    return action == UiJournalAction.block ? blocked : allowed;
  }

  @override
  fetch(Marker m, {DeviceTag? tag, bool append = false}) async {
    fetches++;
  }
}

UiJournalEntry _entry(String domain, UiJournalAction action) => UiJournalEntry(
  deviceName: 'Pixel',
  domainName: domain,
  action: action,
  listId: '',
  profileId: null,
  timestamp: DateTime.utc(2026),
  requests: 1,
  modified: false,
);

void main() {
  group('StatsController', () {
    late _FakeStatsStore store;
    late _FakeDeviceStore device;
    late _FakeJournal journal;
    late StatsController controller;

    void setUp(Marker m) {
      store = _FakeStatsStore();
      device = _FakeDeviceStore();
      journal = _FakeJournal();
      Core.register<StatsStore>(store);
      Core.register<StatsDeltaStore>(_FakeDeltaStore());
      Core.register<DeviceStore>(device);
      Core.register<JournalActor>(journal);
      Core.register<JournalEntriesValue>(JournalEntriesValue());
      controller = StatsController();
      controller.create(m);
    }

    test('Home and Pulse show the same 24h numbers', () async {
      await withTrace((m) async {
        setUp(m);
        await controller.openPulse(m);

        final stats = controller.stats.now;
        final counters = controller.counters.now;
        expect(stats.status, StatsStatus.ready);
        expect(counters.status, StatsStatus.ready);
        expect(counters.data!.counters.blocked, stats.data!.dayBlocked);
        expect(counters.data!.counters.allowed, stats.data!.dayAllowed);
        // No separate 24h counter fetch that could disagree with Home.
        expect(store.calls.where((c) => c.startsWith('counters')), isEmpty);
        expect(controller.toplists.now.data!.blocked.single.tld, 'doubleclick.net');
        expect(controller.recent.now.status, StatsStatus.ready);
      });
    });

    test('changing the range loads that range', () async {
      await withTrace((m) async {
        setUp(m);
        await controller.openPulse(m);
        store.calls.clear();

        await controller.setRange(m, ToplistRange.weekly);

        expect(controller.range.now, ToplistRange.weekly);
        expect(store.calls, containsAll(['counters 7d force=true', 'toplists 7d']));
        final counters = controller.counters.now;
        expect(counters.status, StatsStatus.ready);
        expect(counters.data!.counters.total, 290);
        expect(counters.data!.sparkline!.values, [1, 2, 3]);

        // Back to 24h: the numbers come from the shared stats again.
        await controller.setRange(m, ToplistRange.daily);
        expect(
          controller.counters.now.data!.counters.blocked,
          controller.stats.now.data!.dayBlocked,
        );
        expect(store.calls, contains('toplists 24h'));
      });
    });

    test('Pulse opens on the range it is given', () async {
      await withTrace((m) async {
        setUp(m);
        await controller.openPulse(m, initialRange: ToplistRange.weekly);
        expect(controller.range.now, ToplistRange.weekly);
        expect(store.calls, contains('toplists 7d'));
        expect(controller.counters.now.data!.counters.total, 290);
      });
    });

    test('pull to refresh reloads everything skipping caches', () async {
      await withTrace((m) async {
        setUp(m);
        await controller.openPulse(m);
        store.calls.clear();

        await controller.refreshPulse(m);

        expect(store.calls, containsAll(['day force=true', 'week force=true', 'toplists 24h']));
        expect(journal.fetches, 1);
      });
    });

    test('Home refresh fetches when it starts, once', () async {
      await withTrace((m) async {
        setUp(m);
        controller.setHomeRefresh(true);
        controller.setHomeRefresh(true);
        await pumpEventQueue();
        expect(store.calls, ['day force=false']);
        expect(controller.stats.now.status, StatsStatus.ready);

        controller.setHomeRefresh(false);
        controller.setHomeRefresh(true);
        await pumpEventQueue();
        expect(store.calls, ['day force=false', 'day force=false']);
        controller.setHomeRefresh(false);
      });
    });

    test('sections with nothing to show are empty', () async {
      await withTrace((m) async {
        setUp(m);
        store.next = _uiStats(allowed: 0, blocked: 0);
        store.nextToplist = [];
        journal.blocked = [];
        journal.allowed = [];

        await controller.openPulse(m);

        expect(controller.stats.now.status, StatsStatus.empty);
        expect(controller.counters.now.status, StatsStatus.empty);
        expect(controller.toplists.now.status, StatsStatus.empty);
        expect(controller.recent.now.status, StatsStatus.empty);
      });
    });

    test('a failed fetch shows an error and a retry recovers', () async {
      await withTrace((m) async {
        setUp(m);
        store.failDay = Exception('offline');
        store.failToplists = Exception('offline');
        journal.fail = Exception('offline');

        await controller.openPulse(m);

        expect(controller.stats.now.status, StatsStatus.error);
        expect(controller.counters.now.status, StatsStatus.error);
        expect(controller.toplists.now.status, StatsStatus.error);
        expect(controller.recent.now.status, StatsStatus.error);

        store.failDay = null;
        store.failToplists = null;
        journal.fail = null;
        await controller.retry(m, StatsPart.counters);
        await controller.retry(m, StatsPart.toplists);
        await controller.retry(m, StatsPart.recent);

        expect(controller.stats.now.status, StatsStatus.ready);
        expect(controller.counters.now.status, StatsStatus.ready);
        expect(controller.toplists.now.status, StatsStatus.ready);
        expect(controller.recent.now.status, StatsStatus.ready);
      });
    });

    test('a failed refresh keeps the last numbers with the error', () async {
      await withTrace((m) async {
        setUp(m);
        controller.setHomeRefresh(true);
        await pumpEventQueue();
        final before = controller.stats.now.data;
        controller.setHomeRefresh(false);

        store.failDay = Exception('offline');
        await controller.retry(m, StatsPart.stats);

        expect(controller.stats.now.status, StatsStatus.error);
        expect(controller.stats.now.data, same(before));
      });
    });

    test('waits for the device name, then loads', () async {
      await withTrace((m) async {
        setUp(m);
        device.deviceAlias = '';
        await controller.openPulse(m);
        expect(store.calls.where((c) => c.startsWith('toplists')), isEmpty);
        expect(journal.previews, 0);
        expect(controller.toplists.now.status, StatsStatus.loading);

        device.deviceAlias = 'Pixel';
        await device.changed();
        expect(controller.toplists.now.status, StatsStatus.ready);
        expect(controller.recent.now.status, StatsStatus.ready);
      });
    });

    test('a journal change reloads the recent activity while Pulse is open', () async {
      await withTrace((m) async {
        setUp(m);
        await controller.openPulse(m);
        final before = journal.previews;

        Core.get<JournalEntriesValue>().now = [_entry('new.com', UiJournalAction.block)];
        await pumpEventQueue();
        expect(journal.previews, before + 2);

        controller.closePulse();
        Core.get<JournalEntriesValue>().now = [];
        await pumpEventQueue();
        expect(journal.previews, before + 2);
      });
    });
  });
}
