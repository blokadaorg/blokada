import 'package:common/src/app_variants/v6/module/activation/activation.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/filter/filter.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../../tools.dart';
@GenerateNiceMocks([
  MockSpec<AccountStore>(),
  MockSpec<PlatformPermActor>(),
  MockSpec<StageStore>(),
  MockSpec<DeviceStore>(),
  MockSpec<PlatformFilterActor>(),
  MockSpec<StatsController>(),
  MockSpec<StatsStore>(),
  MockSpec<JournalActor>(),
  MockSpec<NotificationActor>(),
])
import 'activation_actor_test.mocks.dart';

class _Deps {
  final account = MockAccountStore();
  final perm = MockPlatformPermActor();
  final stage = MockStageStore();
  final device = MockDeviceStore();
  final filters = MockPlatformFilterActor();
  final statsController = MockStatsController();
  final stats = MockStatsStore();
  final journal = MockJournalActor();
  final notification = MockNotificationActor();
  final modal = CurrentModalValue();
  final dnsEnabledFor = PrivateDnsEnabledForValue();
  final selectedFilters = SelectedFilters();

  _Deps({ActivationFlow flow = ActivationFlow.guided, bool dnsOn = false, String retention = ""}) {
    when(account.account).thenReturn(
      AccountState(
        "mockedmocked",
        JsonAccount(
          id: "mockedmocked",
          activeUntil: null,
          active: true,
          type: "cloud",
          attributes: {"activation_flow": flow.apiValue},
        ),
      ),
    );
    when(perm.isPrivateDnsEnabled).thenReturn(dnsOn);
    when(stage.route).thenReturn(StageRouteState.init().newFg());
    when(device.retention).thenReturn(retention);
    when(
      stats.countersForRange(any, any, force: anyNamed("force")),
    ).thenAnswer((_) async => const StatsCounters(allowed: 3, blocked: 7, total: 10));
    when(
      journal.fetchPreview(any, action: anyNamed("action"), limit: anyNamed("limit")),
    ).thenAnswer((_) async => []);

    Core.register<AccountStore>(account);
    Core.register<PlatformPermActor>(perm);
    Core.register<StageStore>(stage);
    Core.register<DeviceStore>(device);
    Core.register<PlatformFilterActor>(filters);
    Core.register<StatsController>(statsController);
    Core.register<StatsStore>(stats);
    Core.register<JournalActor>(journal);
    Core.register<NotificationActor>(notification);
    Core.register(modal);
    Core.register(CurrentModalWidgetValue());
    Core.register(dnsEnabledFor);
    Core.register(selectedFilters);
  }

  Future<V6ActivationActor> actor(Marker m) async {
    final actor = V6ActivationActor();
    await actor.onCreate(m);
    await actor.onStart(m);
    return actor;
  }
}

/// Lets the modal listeners, which run on stream events, catch up.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// What BottomManagerSheet does once the user closes the current sheet.
Future<void> _closeSheet(_Deps deps, Marker m) async {
  await deps.modal.change(m, null);
  await _settle();
}

void main() {
  group("cohort", () {
    test("guided cohort runs the flow on a new purchase only", () async {
      await withTrace((m) async {
        final actor = await _Deps().actor(m);
        expect(actor.runsFor(false), isTrue);
        expect(actor.runsFor(true), isFalse);
      });
    });

    test("control cohort keeps the plain DNS wizard", () async {
      await withTrace((m) async {
        final actor = await _Deps(flow: ActivationFlow.control).actor(m);
        expect(actor.runsFor(false), isFalse);
      });
    });

    test("accounts without the attribute are control", () async {
      await withTrace((m) async {
        final deps = _Deps();
        when(deps.account.account).thenReturn(null);
        final actor = await deps.actor(m);
        expect(actor.runsFor(false), isFalse);
      });
    });
  });

  group("goals", () {
    test("each goal maps to one extra blocklist", () {
      expect(ActivationGoal.appAds.blocklist, const BlocklistKey("goodbyeads", "standard"));
      expect(ActivationGoal.trackers.blocklist, const BlocklistKey("ddgtrackerradar", "standard"));
      expect(ActivationGoal.scams.blocklist, const BlocklistKey("phishingarmy", "standard"));
      expect(ActivationGoal.adult.blocklist, const BlocklistKey("oisd", "nsfw"));
      for (final goal in ActivationGoal.values) {
        expect(v6MainBlocklists, isNot(contains(goal.blocklist)));
      }
    });

    test("only lists that differ from the picks change", () {
      final changes = goalChanges(
        {ActivationGoal.appAds, ActivationGoal.scams},
        {
          const BlocklistKey("oisd", "small"),
          const BlocklistKey("oisd", "nsfw"),
          ActivationGoal.scams.blocklist,
        },
      );
      expect(changes, {
        ActivationGoal.appAds.blocklist: true,
        ActivationGoal.adult.blocklist: false,
      });
    });

    test("applyGoals toggles the extras the way the Advanced screen does", () async {
      await withTrace((m) async {
        final deps = _Deps();
        await deps.selectedFilters.change(m, [
          FilterSelection("oisd", ["small", "nsfw"]),
        ]);
        final actor = await deps.actor(m);

        expect(actor.currentGoals(), {ActivationGoal.adult});

        await actor.applyGoals({ActivationGoal.appAds, ActivationGoal.trackers}, m);

        verify(
          deps.filters.toggleExtraBlocklist(ActivationGoal.appAds.blocklist, true, any),
        ).called(1);
        verify(
          deps.filters.toggleExtraBlocklist(ActivationGoal.trackers.blocklist, true, any),
        ).called(1);
        verify(
          deps.filters.toggleExtraBlocklist(ActivationGoal.adult.blocklist, false, any),
        ).called(1);
        verifyNever(deps.filters.toggleExtraBlocklist(ActivationGoal.scams.blocklist, any, any));
        verifyNever(deps.filters.selectMainBlocklist(any, any));
      });
    });
  });

  group("logging", () {
    test("closing the intro without an answer keeps the reminder", () async {
      await withTrace((m) async {
        final deps = _Deps();
        final actor = await deps.actor(m);

        await actor.begin(m);
        expect(deps.modal.present, Modal.activationIntro);
        await _closeSheet(deps, m);

        verify(deps.notification.scheduleActivityLoggingReminder(any)).called(1);
      });
    });

    test("saying no replaces the reminder", () async {
      await withTrace((m) async {
        final deps = _Deps();
        final actor = await deps.actor(m);

        await actor.begin(m);
        await actor.answerLogging(false, m);
        await _closeSheet(deps, m);

        verifyNever(deps.statsController.enableLogging(any));
        verifyNever(deps.notification.scheduleActivityLoggingReminder(any));
        verify(
          deps.notification.dismiss(any, id: NotificationId.activityLoggingReminder),
        ).called(1);
      });
    });

    test("saying yes turns logging on and replaces the reminder", () async {
      await withTrace((m) async {
        final deps = _Deps();
        final actor = await deps.actor(m);

        await actor.begin(m);
        await actor.answerLogging(true, m);
        await _closeSheet(deps, m);

        verify(deps.statsController.enableLogging(any)).called(1);
        verifyNever(deps.notification.scheduleActivityLoggingReminder(any));
      });
    });

    test("a failed opt-in counts as unanswered", () async {
      await withTrace((m) async {
        final deps = _Deps();
        when(deps.statsController.enableLogging(any)).thenThrow(Exception("offline"));
        final actor = await deps.actor(m);

        await actor.begin(m);
        await expectLater(actor.answerLogging(true, m), throwsException);
        await _closeSheet(deps, m);

        verify(deps.notification.scheduleActivityLoggingReminder(any)).called(1);
      });
    });

    test("users with logging off are asked", () async {
      await withTrace((m) async {
        final actor = await _Deps(retention: "").actor(m);
        expect(actor.asksAboutLogging, isTrue);
      });
    });

    test("users with logging already on are not asked", () async {
      await withTrace((m) async {
        final actor = await _Deps(retention: "24h").actor(m);
        expect(actor.asksAboutLogging, isFalse);
      });
    });
  });

  group("setup and first blocks", () {
    test("intro hands over to the DNS sheet while DNS is off", () async {
      await withTrace((m) async {
        final deps = _Deps(dnsOn: false);
        final actor = await deps.actor(m);

        await actor.begin(m);
        await _closeSheet(deps, m);

        expect(deps.modal.present, Modal.onboardPrivateDns);
        expect(actor.step, ActivationStep.setup);
      });
    });

    test("first blocks open once DNS works after setup", () async {
      await withTrace((m) async {
        final deps = _Deps(dnsOn: false);
        final actor = await deps.actor(m);

        await actor.begin(m);
        await _closeSheet(deps, m);
        // iOS: the DNS sheet closes for Settings, then the profile turns on.
        await _closeSheet(deps, m);
        expect(deps.modal.present, isNull);

        when(deps.perm.isPrivateDnsEnabled).thenReturn(true);
        await deps.dnsEnabledFor.change(m, "device-tag");
        await _settle();

        expect(deps.modal.present, Modal.activationFirstBlocks);
        expect(actor.step, ActivationStep.firstBlocks);

        await _closeSheet(deps, m);
        expect(actor.step, ActivationStep.none);
      });
    });

    test("DNS already on goes straight to the first blocks", () async {
      await withTrace((m) async {
        final deps = _Deps(dnsOn: true);
        final actor = await deps.actor(m);

        await actor.begin(m);
        await _closeSheet(deps, m);

        expect(deps.modal.present, Modal.activationFirstBlocks);
      });
    });

    test("first blocks wait for the app to be in front", () async {
      await withTrace((m) async {
        final deps = _Deps(dnsOn: true);
        when(deps.stage.route).thenReturn(StageRouteState.init());
        final actor = await deps.actor(m);

        await actor.begin(m);
        await _closeSheet(deps, m);

        expect(deps.modal.present, isNull);
        expect(actor.step, ActivationStep.setup);
      });
    });

    test("a setup finished long after the purchase skips the first blocks", () async {
      await withTrace((m) async {
        final deps = _Deps(dnsOn: false);
        final actor = await deps.actor(m);
        final purchase = DateTime(2026, 11, 6, 12);
        actor.now = () => purchase;

        await actor.begin(m);
        await _closeSheet(deps, m);
        await _closeSheet(deps, m);

        actor.now = () =>
            purchase.add(V6ActivationActor.firstBlocksWindow + const Duration(minutes: 1));
        when(deps.perm.isPrivateDnsEnabled).thenReturn(true);
        await deps.dnsEnabledFor.change(m, "device-tag");
        await _settle();

        expect(deps.modal.present, isNull);
        expect(actor.step, ActivationStep.none);
      });
    });

    test("the feed shows only with logging on; the counter always", () async {
      expect(firstBlocksModeFor(null), FirstBlocksMode.counterOnly);
      expect(firstBlocksModeFor(""), FirstBlocksMode.counterOnly);
      expect(firstBlocksModeFor("24h"), FirstBlocksMode.feedAndCounter);
    });

    test("polling without logging reads the counter only", () async {
      await withTrace((m) async {
        final deps = _Deps(retention: "");
        final actor = await deps.actor(m);

        final snapshot = await actor.pollFirstBlocks(m);

        expect(snapshot.blocked, 7);
        expect(snapshot.entries, isEmpty);
        verify(deps.stats.countersForRange("24h", any, force: true)).called(1);
        verifyNever(
          deps.journal.fetchPreview(any, action: anyNamed("action"), limit: anyNamed("limit")),
        );
      });
    });

    test("polling with logging also reads the blocked requests", () async {
      await withTrace((m) async {
        final deps = _Deps(retention: "24h");
        final actor = await deps.actor(m);

        await actor.pollFirstBlocks(m);

        verify(deps.journal.fetchPreview(any, action: UiJournalAction.block, limit: 6)).called(1);
      });
    });
  });
}
