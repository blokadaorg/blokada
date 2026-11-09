import 'dart:async';
import 'package:common/src/app_variants/v6/module/home/home.dart';
import 'package:common/src/app_variants/v6/widget/home/actions.dart';
import 'package:common/src/app_variants/v6/widget/home/counter.dart';
import 'package:common/src/app_variants/v6/widget/home/daily/daily_actions.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stats/api.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/platform/stats/toplist_store.dart';
import 'package:common/src/shared/ui/anim/reveal.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show runInAction;
import 'package:mocktail/mocktail.dart';

import '../../../golden/fixtures.dart';
import '../../../golden/golden_tools.dart';

/// Keeps the daily Home's loads out of the test: values are set directly.
class _FakeDailyHome extends DailyHomeActor {
  int shown = 0;
  int expiredLoads = 0;

  @override
  Future<void> onActiveShown(Marker m) async => shown++;

  @override
  Future<void> refreshHeadline(Marker m) async {}

  @override
  Future<void> refreshLastBlock(Marker m) async {}

  @override
  Future<void> refreshTrialBlocked(Marker m) async {}

  @override
  Future<void> refreshExpired(Marker m) async => expiredLoads++;
}

/// Noon [days] calendar days ago, local time: subtracting 24 h steps would
/// land on another calendar day across a daylight saving change.
DateTime _daysAgo(int days) {
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day - days, 12);
}

/// Home's top blocked domain reads answered by [answer], counted. Other
/// toplists (the weekly event's) are empty.
class _Toplists extends ToplistStore {
  int calls = 0;
  late Future<JsonToplistV2Response> Function(int call) answer;

  @override
  Future<JsonToplistV2Response> fetch({
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
    if (limit != 1 || action != 'blocked') return _toplist(null);
    return answer(calls++);
  }
}

JsonToplistV2Response _toplist(String? domain) => JsonToplistV2Response(
  toplist: [
    JsonToplistBucket(
      action: 'blocked',
      entries: [if (domain != null) JsonToplistEntry(name: domain, count: 30)],
    ),
  ],
  window: JsonWindow(label: '24h', start: '', end: ''),
  level: '1',
  limit: 1,
);

class _MockStatsStore extends Mock implements StatsStore {}

class _MockPayment extends Mock implements PaymentActor {}

class _MockPaymentChannel extends Mock implements PaymentChannel {}

void _replace<T extends Object>(T instance) {
  Core.di.allowReassignment = true;
  try {
    Core.register<T>(instance);
  } finally {
    Core.di.allowReassignment = false;
  }
}

void _seedAccount(JsonAccount json) {
  runInAction(() => Core.get<AccountStore>().account = AccountState(json.id, json));
}

JsonAccount _account({
  required bool active,
  String type = 'cloud',
  String? paymentSource,
  String? activeUntil,
  Map<String, dynamic>? attributes,
}) => JsonAccount(
  id: 'testaccount01',
  activeUntil: activeUntil ?? (active ? '2099-01-01T00:00:00Z' : null),
  active: active,
  type: active ? type : 'libre',
  attributes: attributes,
)..paymentSource = paymentSource;

Future<_FakeDailyHome> _boot(
  WidgetTester tester, {
  PlatformType platform = PlatformType.android,
}) async {
  await bootModules(tester, platform: platform);
  await seedCloudAccount(tester);
  final actor = _FakeDailyHome();
  _replace<DailyHomeActor>(actor);
  return actor;
}

Future<void> _show(WidgetTester tester, {bool reduceMotion = false}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const BlokadaApp(
        isFamily: false,
        content: Scaffold(
          body: SingleChildScrollView(child: Center(child: DailyHomeActions())),
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
    registerFallbackValue(Placement.primary);
    registerFallbackValue(DateTime(2026));
  });

  group('DailyHomeActions', () {
    testWidgets('an account that never paid gets the same Home as control', (tester) async {
      final actor = await _boot(tester);
      _seedAccount(_account(active: false));
      seedAppStatus(AppStatus.deactivated);

      await _show(tester);

      expect(find.byType(HomeActions), findsOneWidget);
      expect(tester.widget<HomeActions>(find.byType(HomeActions)).showCards, true);
      expect(find.byType(Reveal), findsNothing);
      expect(actor.shown, 0);
      await _unmount(tester);
    });

    testWidgets('a freemium account gets the same Home as control', (tester) async {
      await _boot(tester, platform: PlatformType.iOS);
      _seedAccount(
        _account(active: false, paymentSource: 'adapty', attributes: {'freemium': true}),
      );
      seedAppStatus(AppStatus.deactivated);

      await _show(tester);

      expect(find.byType(HomeActions), findsOneWidget);
      expect(find.text("home expired action".i18n), findsNothing);
      await _unmount(tester);
    });

    testWidgets('an expired paid account sees the total and resubscribes via winback', (
      tester,
    ) async {
      final actor = await _boot(tester);
      final payment = _MockPayment();
      when(
        () => payment.openPaymentScreen(any(), placement: any(named: 'placement')),
      ).thenAnswer((_) async {});
      _replace<PaymentActor>(payment);
      _seedAccount(
        _account(active: false, paymentSource: 'adapty', activeUntil: '2026-11-03T10:00:00Z'),
      );
      seedAppStatus(AppStatus.deactivated);
      actor.expiredBlocked.now = 12300;

      await _show(tester);

      expect(actor.expiredLoads, 1);
      expect(find.byType(HomeActions), findsNothing);
      expect(find.textContaining("Protection ended on Nov 3"), findsOneWidget);
      expect(find.text("Blokada blocked 12.3K for you."), findsOneWidget);

      await tester.tap(find.text("home expired action".i18n));
      await tester.pump();
      verify(() => payment.openPaymentScreen(any(), placement: Placement.winback)).called(1);
      await _unmount(tester);
    });

    testWidgets('protection on shows status, trial, the counter fallback and Plus', (tester) async {
      final actor = await _boot(tester);
      seedStats();
      seedAppStatus(AppStatus.activatedCloud);
      actor.trial.now = TrialProgress(length: 7, startedAt: _daysAgo(2));
      actor.trialBlocked.now = 640;

      await _show(tester);

      expect(actor.shown, 1);
      // seedStats blocks 36 in the last 24 hours.
      expect(find.text("Protected · 36 blocked in 24 h"), findsOneWidget);
      expect(find.text("Day 3 of 7 · 640 blocked so far"), findsOneWidget);
      // No headline: the 24 hour counter keeps its place.
      expect(find.byType(HomeCounter), findsOneWidget);
      expect(find.text("universal action upgrade".i18n), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a headline replaces the counter and the last block shows with logging', (
      tester,
    ) async {
      final actor = await _boot(tester);
      seedStats();
      seedAppStatus(AppStatus.activatedCloud);
      actor.headline.now = topBlockedHeadline('ads.example', 214);
      actor.lastBlockAt.now = DateTime.now();

      await _show(tester);

      expect(find.text("Most blocked today"), findsOneWidget);
      expect(find.textContaining("ads.example tried to reach your device"), findsOneWidget);
      expect(find.byType(HomeCounter), findsNothing);
      expect(find.text("Protected · last block a moment ago"), findsOneWidget);
      // Outside a trial there is no trial line.
      expect(find.textContaining("Day "), findsNothing);
      await _unmount(tester);
    });

    testWidgets('with protection off the cards hide behind the usual hint', (tester) async {
      final actor = await _boot(tester);
      seedAppStatus(AppStatus.deactivated);

      await _show(tester);

      expect(actor.shown, 0);
      expect(find.text("home action tap to activate".i18n), findsOneWidget);
      // Each card's own fade is the first Opacity under its Reveal.
      final reveals = find.byType(Reveal).evaluate().toList();
      expect(reveals, isNotEmpty);
      for (final reveal in reveals) {
        final fade = find
            .descendant(of: find.byWidget(reveal.widget), matching: find.byType(Opacity))
            .first;
        expect(tester.widget<Opacity>(fade).opacity, 0.0);
      }
      await _unmount(tester);
    });
  });

  group('DailyHomeActor trial', () {
    testWidgets('reads the store trial and drops it once the account is not active', (
      tester,
    ) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      final channel = _MockPaymentChannel();
      final start = _daysAgo(1);
      when(() => channel.fetchActiveSubscriptions(any())).thenAnswer(
        (_) async => [
          StoreSubscription(
            accessLevelId: 'premium',
            store: 'app_store',
            willRenew: true,
            expiresAt: _daysAgo(1 - 7),
            customerUserId: 'testaccount01',
            activatedAt: start,
            introOfferType: 'free_trial',
          ),
        ],
      );
      _replace<PaymentChannel>(channel);
      final actor = Core.get<DailyHomeActor>();

      await tester.runAsync(() => actor.refreshTrial(Markers.testing));
      expect(actor.trial.now?.dayOn(DateTime.now()), 2);
      expect(actor.trial.now?.length, 7);

      _seedAccount(_account(active: false, paymentSource: 'adapty'));
      await tester.runAsync(() => actor.refreshTrial(Markers.testing));
      expect(actor.trial.now, isNull);
      expect(actor.trialBlocked.now, isNull);
    });

    testWidgets('a trial read still running when the account switches is dropped', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      final channel = _MockPaymentChannel();
      final start = _daysAgo(1);
      _replace<PaymentChannel>(channel);
      final actor = Core.get<DailyHomeActor>();

      await tester.runAsync(() async {
        // Created in the real zone, so its completion reaches the actor here.
        final pending = Completer<List<StoreSubscription>>();
        when(() => channel.fetchActiveSubscriptions(any())).thenAnswer((_) => pending.future);
        final read = actor.refreshTrial(Markers.testing);
        await actor.onAccountIdChanged(Markers.testing);
        pending.complete([
          StoreSubscription(
            accessLevelId: 'premium',
            store: 'app_store',
            willRenew: true,
            expiresAt: _daysAgo(1 - 7),
            customerUserId: 'testaccount01',
            activatedAt: start,
            introOfferType: 'free_trial',
          ),
        ]);
        await read;
      });
      expect(actor.trial.now, isNull);
    });
  });

  group('DailyHomeActor late results', () {
    Future<_MockStatsStore> bootStats(WidgetTester tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      final stats = _MockStatsStore();
      when(() => stats.hasStats).thenReturn(false);
      _replace<StatsStore>(stats);
      return stats;
    }

    for (final older in ['finishes', 'fails']) {
      testWidgets('an older trial blocks read that $older last does not win', (tester) async {
        final stats = await bootStats(tester);
        final actor = Core.get<DailyHomeActor>();
        actor.trial.now = TrialProgress(length: 7, startedAt: _daysAgo(1));

        await tester.runAsync(() async {
          final first = Completer<int?>();
          final second = Completer<int?>();
          final answers = [first, second];
          when(
            () => stats.blockedSince(any(), any()),
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

    testWidgets('a headline load for the previous account neither lands nor blocks the new one', (
      tester,
    ) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      seedDevice();
      final toplists = _Toplists();
      _replace<ToplistStore>(toplists);
      final actor = Core.get<DailyHomeActor>();

      await tester.runAsync(() async {
        final old = Completer<JsonToplistV2Response>();
        toplists.answer = (call) => call == 0 ? old.future : Future.value(_toplist('new.example'));
        final oldLoad = actor.refreshHeadline(Markers.testing);
        await actor.onAccountIdChanged(Markers.testing);
        await actor.refreshHeadline(Markers.testing);
        expect(actor.headline.now?.domain, 'new.example');
        old.complete(_toplist('old.example'));
        await oldLoad;
      });
      expect(toplists.calls, 2);
      expect(actor.headline.now?.domain, 'new.example');
    });

    testWidgets('a domain headline still loading when logging is turned off is not shown', (
      tester,
    ) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      seedDevice();
      final toplists = _Toplists();
      _replace<ToplistStore>(toplists);
      final actor = Core.get<DailyHomeActor>();

      await tester.runAsync(() async {
        final pending = Completer<JsonToplistV2Response>();
        toplists.answer = (_) => pending.future;
        final load = actor.refreshHeadline(Markers.testing);
        // The setting alone, before any device refresh tells the actor.
        runInAction(() => Core.get<DeviceStore>().retention = '1h');
        pending.complete(_toplist('ads.example'));
        await load;
      });
      // Another kind (a weekly totals event) may take the slot; no domain may.
      expect(actor.headline.now?.domain, isNull);
    });

    testWidgets('turning logging off hides what it allowed', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      seedDevice();
      final actor = Core.get<DailyHomeActor>();
      await tester.runAsync(() => actor.onDeviceChanged(Markers.testing));
      actor.headline.now = topBlockedHeadline('ads.example', 12);
      actor.lastBlockAt.now = DateTime.now();

      runInAction(() => Core.get<DeviceStore>().retention = '1h');
      await tester.runAsync(() => actor.onDeviceChanged(Markers.testing));

      expect(actor.headline.now, isNull);
      expect(actor.lastBlockAt.now, isNull);
    });

    testWidgets('an account switch reads the new account\'s trial again', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      _seedAccount(_account(active: true, attributes: {'home_variant': 'daily'}));
      final channel = _MockPaymentChannel();
      final start = _daysAgo(1);
      when(() => channel.fetchActiveSubscriptions(any())).thenAnswer(
        (_) async => [
          StoreSubscription(
            accessLevelId: 'premium',
            store: 'app_store',
            willRenew: true,
            expiresAt: _daysAgo(1 - 7),
            customerUserId: 'testaccount01',
            activatedAt: start,
            introOfferType: 'free_trial',
          ),
        ],
      );
      _replace<PaymentChannel>(channel);
      final actor = Core.get<DailyHomeActor>();

      await tester.runAsync(() => actor.onAccountIdChanged(Markers.testing));
      expect(actor.trial.now?.startedAt, start);
    });
  });

  group('Reveal', () {
    Future<void> pumpReveal(WidgetTester tester, {required bool reduce, required int index}) {
      return tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Reveal(visible: true, index: index, child: const Text('card')),
          ),
        ),
      );
    }

    double opacity(WidgetTester tester) => tester.widget<Opacity>(find.byType(Opacity)).opacity;

    testWidgets('fades up 12 px after its stagger', (tester) async {
      await pumpReveal(tester, reduce: false, index: 2);
      await tester.pump(const Duration(milliseconds: 100));
      // Still waiting out 2 × 60 ms.
      expect(opacity(tester), 0);
      expect(tester.widget<Transform>(find.byType(Transform)).transform.getTranslation().y, 12);

      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(Reveal.duration);
      expect(opacity(tester), 1);
      expect(tester.widget<Transform>(find.byType(Transform)).transform.getTranslation().y, 0);
    });

    testWidgets('is a plain fade with Reduce Motion', (tester) async {
      await pumpReveal(tester, reduce: true, index: 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Transform), findsNothing);
      await tester.pump(Reveal.duration);
      expect(opacity(tester), 1);
    });
  });

  group('DailyHomeActor.variantFor', () {
    testWidgets('reads the cohort and keeps daily when the attributes go missing', (tester) async {
      await bootModules(tester);
      final actor = Core.get<DailyHomeActor>();

      expect(actor.variantFor(null), HomeVariant.control);
      expect(actor.variantFor(AccountState('a', _account(active: true))), HomeVariant.control);

      final daily = _account(active: true, attributes: {'home_variant': 'daily'});
      expect(actor.variantFor(AccountState('testaccount01', daily)), HomeVariant.daily);
      // A later copy without attributes (e.g. a stale cache) stays daily.
      expect(
        actor.variantFor(AccountState('testaccount01', _account(active: false))),
        HomeVariant.daily,
      );
    });
  });
}
