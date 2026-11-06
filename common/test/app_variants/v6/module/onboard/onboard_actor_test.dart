import 'package:common/src/app_variants/v6/module/activation/activation.dart';
import 'package:common/src/app_variants/v6/module/onboard/onboard.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../../tools.dart';
@GenerateNiceMocks([MockSpec<V6ActivationActor>(), MockSpec<PlatformPermActor>()])
import 'onboard_actor_test.mocks.dart';

void main() {
  group("V6OnboardActor after a purchase", () {
    Future<(MockV6ActivationActor, CurrentModalValue)> setUp({required bool guided}) async {
      final activation = MockV6ActivationActor();
      when(activation.runsFor(false)).thenReturn(guided);
      when(activation.runsFor(true)).thenReturn(false);
      final perm = MockPlatformPermActor();
      when(perm.isPrivateDnsEnabled).thenReturn(false);
      final modal = CurrentModalValue();
      Core.register<V6ActivationActor>(activation);
      Core.register<PlatformPermActor>(perm);
      Core.register(modal);
      return (activation, modal);
    }

    test("guided cohort starts the activation flow instead of the DNS sheet", () async {
      await withTrace((m) async {
        final (activation, modal) = await setUp(guided: true);

        await V6OnboardActor().showDnsOnboard(false, m);

        verify(activation.begin(any)).called(1);
        expect(modal.present, isNull);
      });
    });

    test("control cohort keeps today's DNS sheet", () async {
      await withTrace((m) async {
        final (activation, modal) = await setUp(guided: false);

        await V6OnboardActor().showDnsOnboard(false, m);

        verifyNever(activation.begin(any));
        expect(modal.present, Modal.onboardPrivateDns);
      });
    });

    test("a restore shows neither", () async {
      await withTrace((m) async {
        final (activation, modal) = await setUp(guided: true);

        await V6OnboardActor().showDnsOnboard(true, m);

        verifyNever(activation.begin(any));
        expect(modal.present, isNull);
      });
    });
  });
}
