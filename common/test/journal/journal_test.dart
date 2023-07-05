import 'package:common/device/device.dart';
import 'package:common/env/env.dart';
import 'package:common/journal/channel.pg.dart';
import 'package:common/journal/journal.dart';
import 'package:common/journal/json.dart';
import 'package:common/stage/stage.dart';
import 'package:common/timer/timer.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
import 'fixtures.dart';
@GenerateNiceMocks([
  MockSpec<JournalStore>(),
  MockSpec<JournalOps>(),
  MockSpec<JournalJson>(),
  MockSpec<TimerService>(),
  MockSpec<StageStore>(),
  MockSpec<EnvStore>(),
  MockSpec<DeviceStore>(),
])
import 'journal_test.mocks.dart';

void main() {
  group("store", () {
    test("willGroupEntriesByRequests", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());
        depend<DeviceStore>(MockDeviceStore());

        final ops = MockJournalOps();
        depend<JournalOps>(ops);

        final timer = MockTimerService();
        depend<TimerService>(timer);

        final env = MockEnvStore();
        when(env.deviceName).thenReturn("deviceName");
        depend<EnvStore>(env);

        final json = MockJournalJson();
        when(json.getEntries(any))
            .thenAnswer((_) => Future.value(fixtureJournalEntries));
        depend<JournalJson>(json);

        final subject = JournalStore();
        await subject.fetch(trace);

        expect(subject.filteredEntries.length, 2);
        expect(subject.filteredEntries[0].requests, 3);
        expect(subject.filteredEntries[0].domainName, "app-measurement.com");
        expect(subject.filteredEntries[1].requests, 4);
        expect(subject.filteredEntries[1].domainName, "latency.discord.media");
      });
    });

    test("willFilterEntries", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());
        depend<DeviceStore>(MockDeviceStore());

        final ops = MockJournalOps();
        depend<JournalOps>(ops);

        final timer = MockTimerService();
        depend<TimerService>(timer);

        final env = MockEnvStore();
        when(env.deviceName).thenReturn("deviceName");
        depend<EnvStore>(env);

        final json = MockJournalJson();
        when(json.getEntries(any))
            .thenAnswer((_) => Future.value(fixtureJournalEntries));
        depend<JournalJson>(json);

        final subject = JournalStore();
        await subject.fetch(trace);

        expect(subject.filteredEntries.length, 2);

        // Search term (not existing)
        await subject.updateFilter(trace, searchQuery: "foo");

        expect(subject.filteredEntries.length, 0);

        // Search term (existing)
        await subject.updateFilter(trace, searchQuery: "discord");

        expect(subject.filteredEntries.length, 1);

        // Device name (need to reset previous filter)
        await subject.updateFilter(trace,
            searchQuery: "", deviceName: "deviceName");

        expect(subject.filteredEntries.length, 2);

        // Blocked only
        await subject.updateFilter(
          trace,
          searchQuery: "",
          deviceName: "",
          showOnly: JournalFilterType.showBlocked,
        );

        expect(subject.filteredEntries.length, 1);
        expect(subject.filteredEntries.first.domainName, "app-measurement.com");

        // Passed only
        await subject.updateFilter(
          trace,
          showOnly: JournalFilterType.showPassed,
        );

        expect(subject.filteredEntries.length, 1);
        expect(
            subject.filteredEntries.first.domainName, "latency.discord.media");
      });
    });

    test("willSortEntries", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());
        depend<DeviceStore>(MockDeviceStore());

        final ops = MockJournalOps();
        depend<JournalOps>(ops);

        final timer = MockTimerService();
        depend<TimerService>(timer);

        final env = MockEnvStore();
        when(env.deviceName).thenReturn("deviceName");
        depend<EnvStore>(env);

        final json = MockJournalJson();
        when(json.getEntries(any))
            .thenAnswer((_) => Future.value(fixtureJournalEntries));
        depend<JournalJson>(json);

        final subject = JournalStore();
        await subject.fetch(trace);

        // Sort by newest first
        await subject.updateFilter(trace, sortNewestFirst: true);

        expect(subject.filteredEntries.first.requests, 3);
        expect(subject.filteredEntries.first.domainName, "app-measurement.com");

        // Sort by most requests first
        await subject.updateFilter(trace, sortNewestFirst: false);

        expect(subject.filteredEntries.first.requests, 4);
        expect(
            subject.filteredEntries.first.domainName, "latency.discord.media");
      });
    });

    test("willRefreshWhenNeeded", () async {
      await withTrace((trace) async {
        depend<DeviceStore>(MockDeviceStore());

        final ops = MockJournalOps();
        depend<JournalOps>(ops);

        final json = MockJournalJson();
        depend<JournalJson>(json);

        final timer = MockTimerService();
        depend<TimerService>(timer);

        final stage = MockStageStore();
        when(stage.route)
            .thenReturn(StageRouteState.init().newTab(StageTab.activity));
        depend<StageStore>(stage);

        final subject = JournalStore();
        verifyNever(json.getEntries(any));

        // Won't refresh if not enabled
        await subject.onDeviceChanged(trace);
        verifyNever(json.getEntries(any));

        // But will, if enabled
        await subject.enableRefresh(trace);
        await subject.onDeviceChanged(trace);
        verify(json.getEntries(any));
      });
    });
  });
}
