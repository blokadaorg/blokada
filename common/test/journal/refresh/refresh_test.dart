import 'package:common/device/device.dart';
import 'package:common/journal/journal.dart';
import 'package:common/journal/refresh/refresh.dart';
import 'package:common/stage/stage.dart';
import 'package:common/timer/timer.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';

import '../../fixtures.dart';
@GenerateNiceMocks([
  MockSpec<TimerService>(),
  MockSpec<JournalStore>(),
  MockSpec<JournalRefreshStore>(),
])
import 'refresh_test.mocks.dart';

void main() {
  group("store", () {
    test("willRefreshWhenNeeded", () async {
      await withTrace((trace) async {
        final store = MockJournalStore();
        di.registerSingleton<JournalStore>(store);

        final subject = JournalRefreshStore();
        verifyNever(store.fetch(any));

        // Won't refresh if not enabled
        await subject.maybeRefresh(trace);
        verifyNever(store.fetch(any));

        // But will, if enabled
        await subject.enableRefresh(trace, true);
        await subject.maybeRefresh(trace);
        verify(store.fetch(any)).called(1);

        // Then it wont refresh (until cooldown time passed)
        await subject.maybeRefresh(trace);
        verifyNever(store.fetch(any));

        // Imagine cooldown passed, should refresh again
        subject.lastRefresh =
            DateTime.now().subtract(const Duration(seconds: 10));
        await subject.maybeRefresh(trace);
        verify(store.fetch(any)).called(1);
      });
    });
  });

  group("binder", () {
    test("onJournalTab", () async {
      await withTrace((trace) async {
        final stage = StageStore();
        di.registerSingleton<StageStore>(stage);

        final timer = MockTimerService();
        di.registerSingleton<TimerService>(timer);

        final store = MockJournalRefreshStore();
        di.registerSingleton<JournalRefreshStore>(store);

        final subject = JournalRefreshBinder();
        verifyNever(store.maybeRefresh(any));

        // When the tab is on, should refresh immediately and with interval
        stage.setReady(trace, true);
        await stage.setActiveTab(trace, StageTab.activity);
        verify(store.maybeRefresh(any)).called(1);
        verify(timer.set(any, any)).called(1);

        // When another tab is on, should stop refreshing
        await stage.setActiveTab(trace, StageTab.settings);
        verify(timer.unset(any)).called(1);
      });
    });

    test("onBackground", () async {
      await withTrace((trace) async {
        final stage = StageStore();
        di.registerSingleton<StageStore>(stage);

        final timer = MockTimerService();
        di.registerSingleton<TimerService>(timer);

        final store = MockJournalRefreshStore();
        di.registerSingleton<JournalRefreshStore>(store);

        final subject = JournalRefreshBinder();
        verifyNever(store.maybeRefresh(any));

        // When the app is in background, stop refreshing
        stage.setReady(trace, true);
        await stage.setForeground(trace, true);
        await stage.setForeground(trace, false);
        verify(timer.unset(any)).called(1);
      });
    });

    test("onTimerFired", () async {
      await withTrace((trace) async {
        final timer = MockTimerService();
        dynamic callback;
        when(timer.addHandler(any, any))
            .thenAnswer((p) => callback = p.positionalArguments[1]);
        di.registerSingleton<TimerService>(timer);

        final store = MockJournalRefreshStore();
        di.registerSingleton<JournalRefreshStore>(store);

        final subject = JournalRefreshBinder();

        // Will register the timer handler
        verify(timer.addHandler(any, any)).called(1);

        // Will re-schedule timer when called from the timer
        await callback();
        verify(timer.set(any, any)).called(1);
      });
    });

    test("onRetentionChanged", () async {
      await withTrace((trace) async {
        final device = DeviceStore();
        di.registerSingleton<DeviceStore>(device);

        final store = MockJournalRefreshStore();
        di.registerSingleton<JournalRefreshStore>(store);

        final timer = MockTimerService();
        di.registerSingleton<TimerService>(timer);

        final subject = JournalRefreshBinder();

        device.retention = "24h";
        verify(store.enableRefresh(any, true)).called(1);

        device.retention = "";
        verify(store.enableRefresh(any, false)).called(1);

        device.retention = null;
        verify(store.enableRefresh(any, false)).called(1);
      });
    });
  });
}
