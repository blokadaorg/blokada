import 'package:common/app/app.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<StageOps>(),
  MockSpec<StageStore>(),
])
import 'stage_test.mocks.dart';

void main() {
  group("store", () {
    test("setForeground", () async {
      await withTrace((trace) async {
        final subject = StageStore();
        subject.setReady(trace, true);
        expect(subject.isForeground, false);

        await subject.setForeground(trace, true);
        expect(subject.isForeground, true);

        await subject.setForeground(trace, false);
        expect(subject.isForeground, false);
      });
    });

    test("setActiveTab", () async {
      await withTrace((trace) async {
        final subject = StageStore();
        subject.setReady(trace, true);
        expect(subject.activeTab, StageTab.unknown);

        await subject.setActiveTab(trace, StageTab.activity);
        expect(subject.activeTab, StageTab.activity);

        await subject.setActiveTab(trace, StageTab.settings);
        expect(subject.activeTab, StageTab.settings);
      });
    });

    test("showModal", () async {
      await withTrace((trace) async {
        final subject = StageStore();
        expect(subject.modal, StageModal.none);

        await subject.showModalNow(trace, StageModal.accountInitFailed);
        expect(subject.modal, StageModal.accountInitFailed);

        await subject.queueModal(trace, StageModal.accountExpired);
        expect(subject.modal, StageModal.accountInitFailed);

        await subject.dismissModal(trace);
        expect(subject.modal, StageModal.accountExpired);

        await subject.dismissModal(trace);
        expect(subject.modal, StageModal.none);

        await subject.queueModal(trace, StageModal.accountExpired);
        expect(subject.modal, StageModal.accountExpired);
      });
    });

    test("dismissModal", () async {
      await withTrace((trace) async {
        final subject = StageStore();
        expect(subject.modal, StageModal.none);

        await subject.showModalNow(trace, StageModal.payment);
        expect(subject.modal, StageModal.payment);

        // We need to ignore some platform events with a cooldown time as they
        // are duplicated.
        await subject.dismissModal(trace, byPlatform: true);
        expect(subject.modal, StageModal.payment);

        await subject.dismissModal(trace, byPlatform: false);
        expect(subject.modal, StageModal.none);
      });
    });
  });

  group("binder", () {
    test("onNavPathChanged", () async {
      await withTrace((trace) async {
        final store = MockStageStore();
        di.registerSingleton<StageStore>(store);

        final subject = StageBinder.forTesting();

        await subject.onNavPathChanged("activity");
        verify(store.setActiveTab(any, StageTab.activity)).called(1);

        await subject.onNavPathChanged("Settings/restore");
        verify(store.setActiveTab(any, StageTab.settings)).called(1);
        verify(store.setTabPayload(any, "restore")).called(1);
      });
    });

    test("onForeground", () async {
      await withTrace((trace) async {
        final store = MockStageStore();
        di.registerSingleton<StageStore>(store);

        final subject = StageBinder.forTesting();

        await subject.onForeground(true);
        verify(store.setForeground(any, true)).called(1);

        await subject.onForeground(false);
        verify(store.setForeground(any, false)).called(1);
      });
    });

    test("onModalDismissed", () async {
      await withTrace((trace) async {
        final store = MockStageStore();
        di.registerSingleton<StageStore>(store);

        final subject = StageBinder.forTesting();

        await subject.onModalDismissedByUser();
        verify(store.dismissModal(any)).called(1);
      });
    });

    test("onModal", () async {
      await withTrace((trace) async {
        final store = StageStore();
        di.registerSingleton<StageStore>(store);

        final ops = MockStageOps();
        di.registerSingleton<StageOps>(ops);

        final subject = StageBinder.forTesting();

        verify(ops.doShowModal("none")).called(1);

        store.showModalNow(trace, StageModal.accountInitFailed);
        verify(ops.doShowModal("accountInitFailed")).called(1);
      });
    });
  });
}
