import 'package:common/env/env.dart';
import 'package:common/journal/channel.pg.dart';
import 'package:common/journal/journal.dart';
import 'package:common/journal/json.dart';
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
])
import 'journal_test.mocks.dart';

void main() {
  group("store", () {
    test("willGroupEntriesByRequests", () async {
      await withTrace((trace) async {
        final env = EnvStore();
        env.setDeviceTag(trace, "deviceName");
        di.registerSingleton<EnvStore>(env);

        final json = MockJournalJson();
        when(json.getEntries(any))
            .thenAnswer((_) => Future.value(fixtureJournalEntries));
        di.registerSingleton<JournalJson>(json);

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
        final env = EnvStore();
        env.setDeviceTag(trace, "deviceName");
        di.registerSingleton<EnvStore>(env);

        final json = MockJournalJson();
        when(json.getEntries(any))
            .thenAnswer((_) => Future.value(fixtureJournalEntries));
        di.registerSingleton<JournalJson>(json);

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
        final env = EnvStore();
        env.setDeviceTag(trace, "deviceName");
        di.registerSingleton<EnvStore>(env);

        final json = MockJournalJson();
        when(json.getEntries(any))
            .thenAnswer((_) => Future.value(fixtureJournalEntries));
        di.registerSingleton<JournalJson>(json);

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
  });

  group("binder", () {
    test("onSearch", () async {
      await withTrace((trace) async {
        final store = MockJournalStore();
        di.registerSingleton<JournalStore>(store);

        final subject = JournalBinder.forTesting();

        verifyNever(store.updateFilter(trace));
        await subject.onSearch("foo");
        verify(store.updateFilter(
          any,
          searchQuery: "foo",
        )).called(1);
      });
    });

    test("onShowForDevice", () async {
      await withTrace((trace) async {
        final store = MockJournalStore();
        di.registerSingleton<JournalStore>(store);

        final subject = JournalBinder.forTesting();

        verifyNever(store.updateFilter(trace));
        await subject.onShowForDevice("deviceName");
        verify(store.updateFilter(
          any,
          deviceName: "deviceName",
        )).called(1);
      });
    });

    test("onShowOnly", () async {
      await withTrace((trace) async {
        final store = MockJournalStore();
        di.registerSingleton<JournalStore>(store);

        final subject = JournalBinder.forTesting();

        verifyNever(store.updateFilter(trace));

        await subject.onShowOnly(true, false); // blocked, passed
        verify(store.updateFilter(
          any,
          showOnly: JournalFilterType.showBlocked,
        )).called(1);

        await subject.onShowOnly(false, true); // blocked, passed
        verify(store.updateFilter(
          any,
          showOnly: JournalFilterType.showPassed,
        )).called(1);

        await subject.onShowOnly(true, true); // blocked, passed
        verify(store.updateFilter(
          any,
          showOnly: JournalFilterType.showAll,
        )).called(1);

        await subject.onShowOnly(false, false); // blocked, passed
        verify(store.updateFilter(
          any,
          showOnly: JournalFilterType.showPassed,
        )).called(1);
      });
    });

    test("onJournalChanged", () async {
      await withTrace((trace) async {
        final env = EnvStore();
        env.setDeviceTag(trace, "deviceName");
        di.registerSingleton<EnvStore>(env);

        final json = MockJournalJson();
        when(json.getEntries(any))
            .thenAnswer((_) => Future.value(fixtureJournalEntries));
        di.registerSingleton<JournalJson>(json);

        final store = JournalStore();
        di.registerSingleton<JournalStore>(store);

        final ops = MockJournalOps();
        di.registerSingleton<JournalOps>(ops);

        final subject = JournalBinder.forTesting();

        // Should notify entries changed after fetching
        verifyNever(ops.doReplaceEntries(any));
        await store.fetch(trace);
        verify(ops.doReplaceEntries(any)).called(1);

        // Should notify entries changed after filter change
        await store.updateFilter(trace, sortNewestFirst: false);
        verify(ops.doReplaceEntries(any)).called(1);

        await store.updateFilter(trace, sortNewestFirst: true);
        verify(ops.doReplaceEntries(any)).called(1);

        await store.updateFilter(trace, searchQuery: "foo");
        verify(ops.doReplaceEntries(any)).called(1);
      });
    });

    test("onFilterChanged", () async {
      await withTrace((trace) async {
        final env = EnvStore();
        env.setDeviceTag(trace, "deviceName");
        di.registerSingleton<EnvStore>(env);

        final json = MockJournalJson();
        when(json.getEntries(any))
            .thenAnswer((_) => Future.value(fixtureJournalEntries));
        di.registerSingleton<JournalJson>(json);

        final ops = MockJournalOps();
        di.registerSingleton<JournalOps>(ops);

        final store = JournalStore();
        di.registerSingleton<JournalStore>(store);

        final subject = JournalBinder.forTesting();
        verifyNever(ops.doFilterChanged(any));

        await store.fetch(trace);
        verifyNever(ops.doFilterChanged(any));

        await store.updateFilter(trace, searchQuery: "foo");
        verify(ops.doFilterChanged(any)).called(1);

        // Setting up exactly same filter should not trigger the callback
        await store.updateFilter(trace, searchQuery: "foo");
        verifyNever(ops.doFilterChanged(any));

        await store.updateFilter(trace,
            searchQuery: null, sortNewestFirst: false);
        verify(ops.doFilterChanged(any)).called(1);

        await store.updateFilter(trace, sortNewestFirst: false);
        verifyNever(ops.doFilterChanged(any));

        await store.updateFilter(trace, sortNewestFirst: true);
        verify(ops.doFilterChanged(any)).called(1);
      });
    });
  });
}
