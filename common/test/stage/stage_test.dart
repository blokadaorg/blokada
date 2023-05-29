import 'package:common/event.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<EventBus>(),
  MockSpec<StageOps>(),
])
import 'stage_test.mocks.dart';

void main() {
  group("store", () {
    test("setForeground", () async {
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final ops = MockStageOps();
        depend<StageOps>(ops);

        final subject = StageStore();
        subject.setReady(trace, true);
        expect(subject.isForeground, false);

        await subject.setForeground(trace, true);
        expect(subject.isForeground, true);

        await subject.setForeground(trace, false);
        expect(subject.isForeground, false);
      });
    });

    test("setRoute", () async {
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final ops = MockStageOps();
        depend<StageOps>(ops);

        final subject = StageStore();
        subject.setReady(trace, true);
        expect(subject.route.tab, StageTab.root);

        await subject.setRoute(trace, "activity");
        expect(subject.route.tab, StageTab.activity);

        await subject.setRoute(trace, "settings");
        expect(subject.route.tab, StageTab.settings);

        await subject.setRoute(trace, "settings/test");
        expect(subject.route.tab, StageTab.settings);
        expect(subject.route.payload, "test");
      });
    });

    test("showModal", () async {
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final ops = MockStageOps();
        depend<StageOps>(ops);

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
        final event = MockEventBus();
        depend<EventBus>(event);

        final ops = MockStageOps();
        depend<StageOps>(ops);

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
}
