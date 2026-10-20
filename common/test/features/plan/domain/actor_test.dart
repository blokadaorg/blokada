import 'package:common/src/core/core.dart';
import 'package:common/src/features/link/domain/link.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/features/plan/domain/plan.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../tools.dart';

class _MockAccountStore extends Mock implements AccountStore {}

class _MockPaymentChannel extends Mock implements PaymentChannel {}

class _MockPaymentActor extends Mock implements PaymentActor {}

class _MockStageStore extends Mock implements StageStore {}

void main() {
  group('PlanActor', () {
    late _MockAccountStore account;
    late _MockPaymentChannel channel;
    late _MockPaymentActor payment;
    late _MockStageStore stage;
    late CurrentPlanValue plan;
    late PlanActor actor;

    setUpAll(() {
      registerFallbackValue(Markers.testing);
      registerFallbackValue(Exception());
      registerFallbackValue(LinkId.manageSubscriptions);
      registerFallbackValue(Placement.primary);
    });

    void seedAccount(String type, String source) {
      final json = JsonAccount(
        id: 'testaccount01',
        activeUntil: '2027-02-14T00:00:00Z',
        active: true,
        type: type,
      );
      json.paymentSource = source;
      when(() => account.account).thenReturn(AccountState('testaccount01', json));
      when(() => account.type).thenReturn(accountTypeFromName(type));
    }

    void setup() {
      account = _MockAccountStore();
      channel = _MockPaymentChannel();
      payment = _MockPaymentActor();
      stage = _MockStageStore();
      plan = CurrentPlanValue();
      Core.register<AccountStore>(account);
      Core.register<PaymentChannel>(channel);
      Core.register<PaymentActor>(payment);
      Core.register<StageStore>(stage);
      Core.register<CurrentPlanValue>(plan);
      actor = PlanActor();
    }

    test('refresh reads renewal from the store', () async {
      await withTrace((m) async {
        setup();
        seedAccount('cloud', 'apple');
        when(() => channel.fetchActiveSubscriptions(any())).thenAnswer(
          (_) async => [
            StoreSubscription(
              accessLevelId: 'cloud',
              store: 'app_store',
              willRenew: false,
              expiresAt: DateTime.utc(2027, 2, 14),
            ),
          ],
        );

        await actor.refresh(m);

        expect(plan.now.renewal, PlanRenewal.ends);
        expect(plan.now.store, PlanStore.appStore);
      });
    });

    test('refresh falls back to active until when the store fails', () async {
      await withTrace((m) async {
        setup();
        seedAccount('cloud', 'apple');
        when(() => channel.fetchActiveSubscriptions(any())).thenThrow(Exception('offline'));

        await actor.refresh(m);

        expect(plan.now.renewal, PlanRenewal.activeUntil);
        expect(plan.now.date, DateTime.utc(2027, 2, 14));
      });
    });

    test('refresh skips the store for an inactive account', () async {
      await withTrace((m) async {
        setup();
        seedAccount('libre', '');

        await actor.refresh(m);

        verifyNever(() => channel.fetchActiveSubscriptions(any()));
        expect(plan.now, Plan.empty);
      });
    });

    test('manage opens the store the plan was bought in', () async {
      await withTrace((m) async {
        setup();
        seedAccount('cloud', 'paypal');
        when(() => channel.fetchActiveSubscriptions(any())).thenAnswer((_) async => []);
        when(() => stage.openLink(any(), any())).thenAnswer((_) async {});

        await actor.refresh(m);
        await actor.manage(m);

        verify(() => stage.openLink(LinkId.manageSubscriptionsWeb, any())).called(1);
      });
    });

    test('upgrade opens the Plus upgrade placement', () async {
      await withTrace((m) async {
        setup();
        when(
          () => payment.openPaymentScreen(any(), placement: any(named: 'placement')),
        ).thenAnswer((_) async {});

        await actor.upgrade(m);

        verify(() => payment.openPaymentScreen(any(), placement: Placement.plusUpgrade)).called(1);
      });
    });

    test('restore with an active purchase checks out as a restore', () async {
      await withTrace((m) async {
        setup();
        seedAccount('cloud', 'apple');
        when(() => channel.restorePurchases(any())).thenAnswer((_) async => 'profile-1');
        when(() => channel.fetchActiveSubscriptions(any())).thenAnswer((_) async => []);
        when(
          () => payment.checkoutSuccessfulPayment(any(), restore: any(named: 'restore')),
        ).thenAnswer((_) async {});

        final outcome = await actor.restorePurchases(m);

        expect(outcome, PlanRestoreOutcome.restored);
        verify(() => payment.checkoutSuccessfulPayment('profile-1', restore: true)).called(1);
      });
    });

    test('restore with nothing active reports not found and skips checkout', () async {
      await withTrace((m) async {
        setup();
        when(() => channel.restorePurchases(any())).thenAnswer((_) async => null);

        final outcome = await actor.restorePurchases(m);

        expect(outcome, PlanRestoreOutcome.notFound);
        verifyNever(() => payment.checkoutSuccessfulPayment(any(), restore: any(named: 'restore')));
      });
    });

    test('restore failure shows the restore-failed path', () async {
      await withTrace((m) async {
        setup();
        when(() => channel.restorePurchases(any())).thenThrow(Exception('store down'));
        when(
          () => payment.handleFailure(
            any(),
            any(),
            any(),
            s: any(named: 's'),
            restore: any(named: 'restore'),
            temporary: any(named: 'temporary'),
          ),
        ).thenAnswer((_) async {});

        final outcome = await actor.restorePurchases(m);

        expect(outcome, PlanRestoreOutcome.failed);
        verify(
          () => payment.handleFailure(
            any(),
            any(),
            any(),
            s: any(named: 's'),
            restore: true,
            temporary: any(named: 'temporary'),
          ),
        ).called(1);
      });
    });
  });
}
