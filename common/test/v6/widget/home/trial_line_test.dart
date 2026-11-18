import 'dart:async';

import 'package:common/src/app_variants/v6/module/home/home.dart';
import 'package:common/src/app_variants/v6/widget/home/trial_line.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart' as api;
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:mocktail/mocktail.dart';

import '../../../golden/fixtures.dart';
import '../../../golden/golden_tools.dart';

/// Keeps the loads out of the widget tests: values are set directly.
class _FakeTrialHome extends TrialHomeActor {
  int trialReads = 0;

  @override
  Future<void> refreshTrial(Marker m) async => trialReads++;

  @override
  Future<void> refreshTrialBlocked(Marker m) async {}
}

class _MockStatsStore extends Mock implements StatsStore {}

class _MockPaymentChannel extends Mock implements PaymentChannel {}

void _replace<T extends Object>(T instance) {
  Core.di.allowReassignment = true;
  try {
    Core.register<T>(instance);
  } finally {
    Core.di.allowReassignment = false;
  }
}

/// Noon [days] calendar days ago, local time: subtracting 24 h steps would
/// land on another calendar day across a daylight saving change.
DateTime _daysAgo(int days) {
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day - days, 12);
}

StoreSubscription _trialSub({String owner = 'testaccount01'}) => StoreSubscription(
  accessLevelId: 'premium',
  store: 'app_store',
  willRenew: true,
  expiresAt: _daysAgo(1 - 7),
  customerUserId: owner,
  activatedAt: _daysAgo(1),
  introOfferType: 'free_trial',
);

Future<void> _show(WidgetTester tester, {double textScale = 1.0, double width = 320}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, 640), textScaler: TextScaler.linear(textScale)),
      child: BlokadaApp(
        isFamily: false,
        content: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: const TrialLine()),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 10));
}

void main() {
  setUpAll(() {
    registerFallbackValue(Markers.testing);
    registerFallbackValue(DateTime(2026));
  });

  group('TrialLine', () {
    testWidgets('shows nothing outside a trial', (tester) async {
      await bootModules(tester);
      _replace<TrialHomeActor>(_FakeTrialHome());
      seedAppStatus(AppStatus.activatedCloud);

      await _show(tester);

      expect(find.textContaining('Day '), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await _unmount(tester);
    });

    testWidgets('shows the day and what was blocked since the trial started', (tester) async {
      await bootModules(tester);
      final actor = _FakeTrialHome();
      _replace<TrialHomeActor>(actor);
      seedAppStatus(AppStatus.activatedCloud);
      actor.trial.now = TrialProgress(length: 7, startedAt: _daysAgo(2));
      actor.trialBlocked.now = 1240;

      await _show(tester);

      expect(find.text('Day 3 of 7 · 1.2K blocked so far'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('hides once the trial has ended, without a store read', (tester) async {
      await bootModules(tester);
      final actor = _FakeTrialHome();
      _replace<TrialHomeActor>(actor);
      seedAppStatus(AppStatus.activatedCloud);
      actor.trial.now = TrialProgress(
        length: 7,
        startedAt: _daysAgo(7),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      await _show(tester);

      expect(find.textContaining('Day '), findsNothing);
      expect(actor.trialReads, 1);
      await _unmount(tester);
    });

    testWidgets('does not read the store while Home is covered', (tester) async {
      await bootModules(tester);
      final actor = _FakeTrialHome();
      _replace<TrialHomeActor>(actor);
      seedAppStatus(AppStatus.activatedCloud);
      final enabled = ValueNotifier(false);

      await tester.pumpWidget(
        BlokadaApp(
          isFamily: false,
          content: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (_, on, _) => TickerMode(
                enabled: on,
                child: const Center(child: TrialLine()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(actor.trialReads, 0);

      enabled.value = true;
      await tester.pump();
      expect(actor.trialReads, 1);
      await _unmount(tester);
    });

    testWidgets('hides at the end of the trial between stats refreshes', (tester) async {
      await bootModules(tester);
      final actor = _FakeTrialHome();
      _replace<TrialHomeActor>(actor);
      seedAppStatus(AppStatus.activatedCloud);
      // One clock for the timer and the drawn line: the binding's fake one.
      trialLineNow = () => tester.binding.clock.now();
      addTearDown(() => trialLineNow = DateTime.now);
      actor.trial.now = TrialProgress(
        length: 7,
        startedAt: _daysAgo(6),
        expiresAt: trialLineNow().add(const Duration(seconds: 5)),
      );

      await _show(tester);
      expect(find.textContaining('Day '), findsOneWidget);

      // _show pumped 1 s; just before the deadline the line still shows.
      await tester.pump(const Duration(milliseconds: 3900));
      expect(find.textContaining('Day '), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Day '), findsNothing);
      expect(actor.trialReads, 1);
      await _unmount(tester);
    });

    testWidgets('a zero count shows the day only', (tester) async {
      await bootModules(tester);
      final actor = _FakeTrialHome();
      _replace<TrialHomeActor>(actor);
      seedAppStatus(AppStatus.activatedCloud);
      actor.trial.now = TrialProgress(length: 7, startedAt: _daysAgo(0));
      actor.trialBlocked.now = 0;

      await _show(tester);

      expect(find.text('Day 1 of 7'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('reads the trial when protection comes on', (tester) async {
      await bootModules(tester);
      final actor = _FakeTrialHome();
      _replace<TrialHomeActor>(actor);
      seedAppStatus(AppStatus.deactivated);

      await _show(tester);
      expect(actor.trialReads, 0);

      seedAppStatus(AppStatus.activatedCloud);
      await tester.pump();
      expect(actor.trialReads, 1);
      await _unmount(tester);
    });

    // The longest realistic line: German, a narrow phone, the largest text.
    testWidgets('stays inside a narrow screen at the largest text size', (tester) async {
      await bootModules(tester);
      final actor = _FakeTrialHome();
      _replace<TrialHomeActor>(actor);
      seedAppStatus(AppStatus.activatedCloud);
      actor.trial.now = TrialProgress(length: 14, startedAt: _daysAgo(9));
      actor.trialBlocked.now = 1234567;

      await _show(tester, textScale: 3.0, width: 320);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TrialLine)).width, lessThanOrEqualTo(320));
      await _unmount(tester);
    });
  });

  group('TrialHomeActor', () {
    testWidgets('reads the store trial and drops it once the account is not active', (
      tester,
    ) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      final channel = _MockPaymentChannel();
      when(() => channel.fetchActiveSubscriptions(any())).thenAnswer((_) async => [_trialSub()]);
      _replace<PaymentChannel>(channel);
      final actor = Core.get<TrialHomeActor>();

      await tester.runAsync(() => actor.refreshTrial(Markers.testing));
      expect(actor.trial.now?.dayOn(DateTime.now()), 2);
      expect(actor.trial.now?.length, 7);

      runInAction(() {
        final json = JsonAccount(
          id: 'testaccount01',
          activeUntil: null,
          active: false,
          type: 'libre',
        );
        Core.get<AccountStore>().account = AccountState(json.id, json);
      });
      await tester.runAsync(() => actor.refreshTrial(Markers.testing));
      expect(actor.trial.now, isNull);
      expect(actor.trialBlocked.now, isNull);
    });

    testWidgets('a read failure only hides the line', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      final channel = _MockPaymentChannel();
      when(() => channel.fetchActiveSubscriptions(any())).thenThrow(Exception('store down'));
      _replace<PaymentChannel>(channel);
      final actor = Core.get<TrialHomeActor>();

      await tester.runAsync(() => actor.refreshTrial(Markers.testing));
      expect(actor.trial.now, isNull);
    });

    testWidgets('a trial read still running when the account switches is dropped', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      final channel = _MockPaymentChannel();
      _replace<PaymentChannel>(channel);
      final actor = Core.get<TrialHomeActor>();

      await tester.runAsync(() async {
        // Created in the real zone, so its completion reaches the actor here.
        final pending = Completer<List<StoreSubscription>>();
        when(() => channel.fetchActiveSubscriptions(any())).thenAnswer((_) => pending.future);
        final read = actor.refreshTrial(Markers.testing);
        // The switch's own read finds no trial.
        when(() => channel.fetchActiveSubscriptions(any())).thenAnswer((_) async => []);
        await actor.onAccountIdChanged(Markers.testing);
        await actor.lastBackgroundRefresh;
        pending.complete([_trialSub()]);
        await read;
      });
      expect(actor.trial.now, isNull);
    });

    testWidgets('an account refresh reads the store only around a trial or a purchase', (
      tester,
    ) async {
      await bootModules(tester);
      final channel = _MockPaymentChannel();
      when(() => channel.fetchActiveSubscriptions(any())).thenAnswer((_) async => [_trialSub()]);
      _replace<PaymentChannel>(channel);
      final actor = Core.get<TrialHomeActor>();
      void seed({required bool active}) => runInAction(() {
        final json = JsonAccount(
          id: 'testaccount01',
          activeUntil: active ? '2099-01-01T00:00:00Z' : null,
          active: active,
          type: active ? 'cloud' : 'libre',
        );
        Core.get<AccountStore>().account = AccountState(json.id, json);
      });

      Future<void> changed() => tester.runAsync(() async {
        await actor.onAccountChanged(Markers.testing);
        await actor.lastBackgroundRefresh;
      });

      // An active account seen for the first time, and refreshed again.
      seed(active: true);
      await changed();
      await changed();
      verifyNever(() => channel.fetchActiveSubscriptions(any()));

      // A purchase: inactive, then active.
      seed(active: false);
      await changed();
      seed(active: true);
      await changed();
      verify(() => channel.fetchActiveSubscriptions(any())).called(1);
      expect(actor.trial.now?.length, 7);

      // While a trial shows, each refresh re-reads it (it may have converted).
      await changed();
      verify(() => channel.fetchActiveSubscriptions(any())).called(1);
    });

    testWidgets("an account switch reads the new account's trial again", (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      final channel = _MockPaymentChannel();
      when(() => channel.fetchActiveSubscriptions(any())).thenAnswer((_) async => [_trialSub()]);
      _replace<PaymentChannel>(channel);
      final actor = Core.get<TrialHomeActor>();

      await tester.runAsync(() async {
        await actor.onAccountIdChanged(Markers.testing);
        await actor.lastBackgroundRefresh;
      });
      expect(actor.trial.now?.length, 7);
    });

    testWidgets('a lapse while the first store read runs drops that read', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      final channel = _MockPaymentChannel();
      _replace<PaymentChannel>(channel);
      final actor = Core.get<TrialHomeActor>();

      await tester.runAsync(() async {
        final pending = Completer<List<StoreSubscription>>();
        when(() => channel.fetchActiveSubscriptions(any())).thenAnswer((_) => pending.future);
        final read = actor.refreshTrial(Markers.testing);
        runInAction(() {
          final json = JsonAccount(
            id: 'testaccount01',
            activeUntil: null,
            active: false,
            type: 'libre',
          );
          Core.get<AccountStore>().account = AccountState(json.id, json);
        });
        await actor.onAccountChanged(Markers.testing);
        await actor.lastBackgroundRefresh;
        pending.complete([_trialSub()]);
        await read;
      });
      expect(actor.trial.now, isNull);
      verify(() => channel.fetchActiveSubscriptions(any())).called(1);
    });

    testWidgets('a new trial start clears the previous count until it is summed', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      final channel = _MockPaymentChannel();
      when(() => channel.fetchActiveSubscriptions(any())).thenAnswer((_) async => [_trialSub()]);
      _replace<PaymentChannel>(channel);
      final stats = _MockStatsStore();
      when(() => stats.hasStats).thenReturn(false);
      _replace<StatsStore>(stats);
      final actor = Core.get<TrialHomeActor>();
      actor.trial.now = TrialProgress(length: 7, startedAt: _daysAgo(5));
      actor.trialBlocked.now = 900;

      int? countWhileSumming = -1;
      when(() => stats.blockedSince(any(), any(), accountId: any(named: 'accountId'))).thenAnswer((
        _,
      ) async {
        countWhileSumming = actor.trialBlocked.now;
        return 20;
      });
      await tester.runAsync(() => actor.refreshTrial(Markers.testing));

      expect(countWhileSumming, isNull);
      expect(actor.trialBlocked.now, 20);
    });

    testWidgets('a longer trial is counted while its start is in the two weeks', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      final stats = _MockStatsStore();
      when(() => stats.hasStats).thenReturn(false);
      when(
        () => stats.blockedSince(any(), any(), accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => 70);
      _replace<StatsStore>(stats);
      final actor = Core.get<TrialHomeActor>();

      actor.trial.now = TrialProgress(length: 30, startedAt: _daysAgo(2));
      await tester.runAsync(() => actor.refreshTrialBlocked(Markers.testing));
      expect(actor.trialBlocked.now, 70);

      // Started before the two weeks of stats: day only, not a partial sum.
      actor.trial.now = TrialProgress(length: 30, startedAt: _daysAgo(20));
      await tester.runAsync(() => actor.refreshTrialBlocked(Markers.testing));
      expect(actor.trialBlocked.now, isNull);
    });

    testWidgets('the count is read for the current account, not the shared id', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      final stats = _MockStatsStore();
      when(() => stats.hasStats).thenReturn(false);
      when(
        () => stats.blockedSince(any(), any(), accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => 1);
      _replace<StatsStore>(stats);
      final actor = Core.get<TrialHomeActor>();
      actor.trial.now = TrialProgress(length: 7, startedAt: _daysAgo(1));
      // The shared id still names another account, as after a restore that
      // changes only the id.
      await tester.runAsync(() => Core.get<api.AccountId>().change(Markers.testing, 'previous01'));

      await tester.runAsync(() => actor.refreshTrialBlocked(Markers.testing));
      verify(
        () => stats.blockedSince(any(), any(), accountId: Core.get<AccountStore>().id),
      ).called(1);
      verifyNever(() => stats.blockedSince(any(), any(), accountId: 'previous01'));
    });

    for (final older in ['finishes', 'fails']) {
      testWidgets('an older blocked count that $older last does not win', (tester) async {
        await bootModules(tester);
        await seedCloudAccount(tester);
        final stats = _MockStatsStore();
        when(() => stats.hasStats).thenReturn(false);
        _replace<StatsStore>(stats);
        final actor = Core.get<TrialHomeActor>();
        actor.trial.now = TrialProgress(length: 7, startedAt: _daysAgo(1));

        await tester.runAsync(() async {
          final first = Completer<int?>();
          final second = Completer<int?>();
          final answers = [first, second];
          when(
            () => stats.blockedSince(any(), any(), accountId: any(named: 'accountId')),
          ).thenAnswer((_) => answers.removeAt(0).future);
          final olderRead = actor.refreshTrialBlocked(Markers.testing);
          final newerRead = actor.refreshTrialBlocked(Markers.testing);
          second.complete(50);
          await newerRead;
          if (older == 'fails') {
            first.completeError(Exception('offline'));
          } else {
            first.complete(10);
          }
          await olderRead;
        });
        expect(actor.trialBlocked.now, 50);
      });
    }
  });
}
