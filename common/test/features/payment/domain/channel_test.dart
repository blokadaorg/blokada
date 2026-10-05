import 'package:common/src/core/core.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../tools.dart';

class _MockPaymentActor extends Mock implements PaymentActor {}

void main() {
  group('PaymentCommand', () {
    late _MockPaymentActor actor;
    late CommandCoordinator commands;

    setUpAll(() {
      registerFallbackValue(Exception());
    });

    Future<void> setup(Marker m) async {
      actor = _MockPaymentActor();
      Core.register<PaymentActor>(actor);
      commands = CommandCoordinator();
      await commands.registerCommands(m, PaymentCommand().onRegisterCommands());
    }

    test('success reads profileId and restore from separate args', () async {
      await withTrace((m) async {
        await setup(m);
        when(
          () => actor.checkoutSuccessfulPayment(any(), restore: any(named: 'restore')),
        ).thenAnswer((_) async {});

        await commands.execute(m, cmdPaymentHandleSuccess, ["profile-1", "1"]);
        verify(() => actor.checkoutSuccessfulPayment("profile-1", restore: true)).called(1);

        await commands.execute(m, cmdPaymentHandleSuccess, ["profile-2", "0"]);
        verify(() => actor.checkoutSuccessfulPayment("profile-2", restore: false)).called(1);
      });
    });

    test('failure reads restore and temporary flags', () async {
      await withTrace((m) async {
        await setup(m);
        when(
          () => actor.handleFailure(
            any(),
            any(),
            any(),
            restore: any(named: 'restore'),
            temporary: any(named: 'temporary'),
          ),
        ).thenAnswer((_) async {});

        await commands.execute(m, cmdPaymentHandleFailure, ["1", "0"]);
        verify(
          () => actor.handleFailure(any(), any(), any(), restore: true, temporary: false),
        ).called(1);
      });
    });

    test('screen closed requires the isError arg', () async {
      await withTrace((m) async {
        await setup(m);
        when(
          () => actor.handleScreenClosed(any(), isError: any(named: 'isError')),
        ).thenAnswer((_) async {});

        await commands.execute(m, cmdPaymentHandleScreenClosed, ["1"]);
        verify(() => actor.handleScreenClosed(any(), isError: true)).called(1);

        await expectLater(commands.execute(m, cmdPaymentHandleScreenClosed, null), throwsException);
      });
    });
  });
}
