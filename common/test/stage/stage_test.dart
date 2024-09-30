import 'dart:async';

import 'package:common/dragon/scheduler.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:common/stage/stage.dart';
import 'package:common/timer/timer.dart';
import 'package:common/util/async.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<StageOps>(),
  MockSpec<Scheduler>(),
  MockSpec<TimerService>(),
])
import 'stage_test.mocks.dart';

void main() {
  group("store", () {
    test("setBackground", () async {
      await withTrace((m) async {
        final ops = MockStageOps();
        depend<StageOps>(ops);
        depend<Scheduler>(MockScheduler());

        final subject = StageStore();
        subject.act = mockedAct;
        await subject.setReady(true, m);
        expect(subject.route.isForeground(), false);

        await subject.setForeground(m);

        await subject.setRoute("home", m);
        expect(subject.route.isForeground(), true);

        await subject.setBackground(m);
        expect(subject.route.isForeground(), false);
      });
    });

    test("setRoute", () async {
      await withTrace((m) async {
        final ops = MockStageOps();
        depend<StageOps>(ops);
        depend<Scheduler>(MockScheduler());

        final subject = StageStore();
        subject.act = mockedAct;
        await subject.setReady(true, m);
        await subject.setForeground(m);

        await subject.setRoute("activity", m);
        expect(subject.route.isBecameTab(StageTab.activity), true);

        await subject.setRoute("settings", m);
        expect(subject.route.isBecameTab(StageTab.settings), true);

        await subject.setRoute("settings/test", m);
        expect(subject.route.isTab(StageTab.settings), true);
        expect(subject.route.route.payload, "test");
      });
    });

    test("showModal", () async {
      await withTrace((m) async {
        final ops = MockStageOps();
        depend<StageOps>(ops);
        depend<Scheduler>(MockScheduler());

        final subject = StageStore();
        subject.act = mockedAct;
        await subject.setReady(true, m);
        await subject.setForeground(m);
        expect(subject.route.modal, null);

        _simulateConfirmation(() async {
          await subject.modalShown(StageModal.plusLocationSelect, m);
        });

        await subject.showModal(StageModal.plusLocationSelect, m);
        expect(subject.route.modal, StageModal.plusLocationSelect);

        _simulateConfirmation(() async {
          await subject.modalDismissed(m);
        });

        await subject.dismissModal(m);
        expect(subject.route.modal, null);
      });
    });

    test("backgroundAndModal", () async {
      await withTrace((m) async {
        final ops = MockStageOps();
        depend<StageOps>(ops);
        depend<Scheduler>(MockScheduler());

        final subject = StageStore();
        subject.act = mockedAct;
        await subject.setReady(true, m);
        expect(subject.route.isForeground(), false);
        expect(subject.route.modal, null);

        await subject.setForeground(m);

        await subject.setRoute("home", m);
        expect(subject.route.isForeground(), true);

        _simulateConfirmation(() async {
          await subject.modalShown(StageModal.payment, m);
        });

        await subject.showModal(StageModal.payment, m);
        expect(subject.route.modal, StageModal.payment);

        await subject.setBackground(m);
        await subject.setBackground(m); // double event on purpose
        expect(subject.route.isForeground(), false);

        await subject.setForeground(m);
        await subject.setForeground(m);
        expect(subject.route.modal, StageModal.payment);
      });
    });

    test("advancedModalManagement", () async {
      await withTrace((m) async {
        final ops = MockStageOps();
        depend<StageOps>(ops);
        depend<Scheduler>(MockScheduler());

        final subject = StageStore();
        subject.act = mockedAct;
        await subject.setReady(true, m);
        await subject.setForeground(m);
        expect(subject.route.modal, null);

        // _simulateConfirmation(() async {
        //   await subject.modalShown(StageModal.help);
        // });
        //
        // await subject.showModal(StageModal.help);
        // expect(subject.route.modal, StageModal.help);

        // User having one sheet opened and opening another one
        _simulateConfirmation(() async {
          await subject.modalDismissed(m);
          await sleepAsync(const Duration(milliseconds: 600));
          _simulateConfirmation(() async {
            await subject.modalShown(StageModal.plusLocationSelect, m);
          });
        });
        await subject.showModal(StageModal.plusLocationSelect, m);
        expect(subject.route.modal, StageModal.plusLocationSelect);

        // Same but manual dismiss
        _simulateConfirmation(() async {
          await subject.modalDismissed(m);
        });
        await subject.dismissModal(m);
        _simulateConfirmation(() async {
          await subject.modalShown(StageModal.help, m);
        });
        await subject.showModal(StageModal.help, m);

        expect(subject.route.modal, StageModal.help);
      });
    });

    test("delayedEvents", () async {
      await withTrace((m) async {
        final ops = MockStageOps();
        depend<StageOps>(ops);
        depend<Scheduler>(MockScheduler());

        final subject = StageStore();
        subject.act = mockedAct;

        // Stage is not ready, should save this route for later
        await subject.setRoute("activity", m);
        expect(subject.route.isBecameTab(StageTab.activity), false);

        await subject.setReady(true, m);
        await subject.setForeground(m);

        expect(subject.route.isBecameTab(StageTab.activity), true);

        // When going bg, events wait until foreground
        await subject.setBackground(m);
        expect(subject.route.modal, null);

        // This one gets saved
        await subject.showModal(StageModal.plusLocationSelect, m);
        expect(subject.route.modal, null);

        _simulateConfirmation(() async {
          await subject.modalShown(StageModal.plusLocationSelect, m);
        });

        // Now modal will be shown
        await subject.setForeground(m);
        expect(subject.route.modal, StageModal.plusLocationSelect);
      });
    });

    test("routeChanged", () async {
      await withTrace((m) async {
        final ops = MockStageOps();
        depend<StageOps>(ops);
        depend<Scheduler>(MockScheduler());
        depend<TimerService>(MockTimerService());

        final subject = StageStore();
        subject.act = mockedAct;

        int counter = 0;
        subject.addOnValue(routeChanged, (route, m) {
          expect(route.isForeground(), counter++ != 1);
        });

        await subject.setReady(true, m);
        await subject.setBackground(m);
        await subject.setForeground(m);
      });
    });
  });

  group("stageRouteState", () {
    test("basicTest", () async {
      await withTrace((m) async {
        // Init state (background)
        StageRouteState route = StageRouteState.init();

        expect(route.isForeground(), false);
        expect(route.isBecameForeground(), false);
        expect(route.isTab(StageTab.home), false);
        expect(route.isBecameTab(StageTab.home), false);
        expect(route.isMainRoute(), true);

        // Opened home tab (foreground)
        route = route.newTab(StageTab.home);

        expect(route.isForeground(), true);
        expect(route.isBecameForeground(), true);
        expect(route.isTab(StageTab.home), true);
        expect(route.isBecameTab(StageTab.home), true);
        expect(route.isMainRoute(), true);

        // Opened a sheet, same tab
        route = route.newModal(StageModal.plusLocationSelect);

        expect(route.isForeground(), true);
        expect(route.isBecameForeground(), false);
        expect(route.isBecameTab(StageTab.home), false);
        expect(route.isTab(StageTab.home), true);
        expect(route.isMainRoute(), false);
        expect(route.isModal(StageModal.plusLocationSelect), true);

        // Dismissed the sheet, same tab, should not report this tab again
        route = route.newModal(null);

        expect(route.isBecameForeground(), false);
        expect(route.isBecameTab(StageTab.home), false);
        expect(route.isTab(StageTab.home), true);
        expect(route.isMainRoute(), true);
        expect(route.isModal(StageModal.plusLocationSelect), false);

        // Another tab
        route = route.newTab(StageTab.settings);

        expect(route.isBecameForeground(), false);
        expect(route.isBecameTab(StageTab.settings), true);
        expect(route.isMainRoute(), true);

        // Deep navigation within tab
        route = route.newRoute(StageRoute.fromPath("settings/account"));

        expect(route.isBecameForeground(), false);
        expect(route.isBecameTab(StageTab.settings), false);
        expect(route.isTab(StageTab.settings), true);
        expect(route.isMainRoute(), false);
        expect(route.route.payload, "account");

        // Background
        route = route.newBg();

        expect(route.isForeground(), false);
        expect(route.isBecameForeground(), false);

        // Came back to deep navigation, should report this tab again
        route = route.newRoute(StageRoute.fromPath("settings/account"));

        expect(route.isBecameForeground(), true);
        expect(route.isBecameTab(StageTab.settings), true);
        expect(route.isMainRoute(), false);

        // Navigate home, open a sheet, and then go bg
        route = route.newTab(StageTab.home);
        route = route.newModal(StageModal.plusLocationSelect);
        route = route.newBg();

        expect(route.isForeground(), false);
        expect(route.isBecameForeground(), false);
        expect(route.isModal(StageModal.plusLocationSelect), true);
        expect(route.isBecameModal(StageModal.plusLocationSelect), false);
        expect(route.isMainRoute(), false);

        // Coming back to foreground
        route = route.newTab(StageTab.home);

        expect(route.isForeground(), true);
        expect(route.isBecameForeground(), true);
        expect(route.isModal(StageModal.plusLocationSelect), true);
        expect(route.isBecameModal(StageModal.plusLocationSelect), false);
        expect(route.isMainRoute(), false);

        // Open another sheet
        route = route.newModal(StageModal.help);
        expect(route.isModal(StageModal.help), true);
        expect(route.isBecameModal(StageModal.help), true);

        // Modal, Bg, hack fg, see if modal preserved
        route = route.newBg();
        route = StageRouteState.init().newFg(m: StageModal.help);
        expect(route.isForeground(), true);
        expect(route.isBecameForeground(), true);
        expect(route.isModal(StageModal.help), true);
      });
    });
  });
}

_simulateConfirmation(Function callback) {
  // Simulate the confirmation coming after a while
  Timer(const Duration(milliseconds: 1), () async {
    await callback();
  });
}
