import 'package:common/src/core/core.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../tools.dart';

class _MockStageStore extends Mock implements StageStore {}

void main() {
  group('PaymentActor.handleFailure', () {
    late _MockStageStore stage;
    late PaymentActor actor;

    setUpAll(() {
      registerFallbackValue(Markers.testing);
      registerFallbackValue(StageModal.paymentFailed);
    });

    void setup() {
      stage = _MockStageStore();
      when(() => stage.showModal(any(), any())).thenAnswer((_) async {});
      Core.register<StageStore>(stage);
      actor = PaymentActor();
    }

    test('the paywall shows only the first error until it opens again', () async {
      await withTrace((m) async {
        setup();

        await actor.handleFailure(m, "first", Exception());
        await actor.handleFailure(m, "second", Exception(), restore: true);

        verify(() => stage.showModal(StageModal.paymentFailed, any())).called(1);
        verifyNever(() => stage.showModal(StageModal.accountRestoreFailed, any()));
      });
    });

    test('reportAlways shows the failure even after an earlier one', () async {
      await withTrace((m) async {
        setup();

        await actor.handleFailure(m, "paywall", Exception());
        await actor.handleFailure(m, "settings", Exception(), restore: true, reportAlways: true);

        verify(() => stage.showModal(StageModal.accountRestoreFailed, any())).called(1);
      });
    });
  });
}
