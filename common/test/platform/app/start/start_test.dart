import 'package:common/common/module/payment/payment.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/account/refresh/refresh.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/app/start/start.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/perm/perm.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/plus/module/vpn/vpn.dart';
import 'package:common/plus/plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';
@GenerateNiceMocks([
  MockSpec<AppStore>(),
  MockSpec<Scheduler>(),
  MockSpec<AppStartStore>(),
  MockSpec<DeviceStore>(),
  MockSpec<PlatformPermActor>(),
  MockSpec<AccountStore>(),
  MockSpec<StageStore>(),
  MockSpec<AccountRefreshStore>(),
  MockSpec<VpnActor>(),
  MockSpec<PlusActor>(),
  MockSpec<PaymentActor>(),
])
import 'start_test.mocks.dart';

void main() {
  group("store", () {
    test("pauseAppUntil", () async {
      await withTrace((m) async {
        final app = MockAppStore();
        Core.register<AppStore>(app);

        Core.register<PlusActor>(MockPlusActor());

        final device = MockDeviceStore();
        Core.register<DeviceStore>(device);

        final timer = MockScheduler();
        Core.register<Scheduler>(timer);

        final subject = AppStartStore();

        await subject.pauseAppUntil(const Duration(seconds: 30), m);

        verify(app.appPaused(true, m)).called(1);
        verify(device.setCloudEnabled(false, m)).called(1);
        verify(timer.addOrUpdate(any)).called(1);
      });
    });

    test("pauseAppIndefinitely", () async {
      await withTrace((m) async {
        final app = MockAppStore();
        Core.register<AppStore>(app);

        Core.register<PlusActor>(MockPlusActor());

        final device = MockDeviceStore();
        Core.register<DeviceStore>(device);

        final timer = MockScheduler();
        Core.register<Scheduler>(timer);

        final subject = AppStartStore();

        await subject.pauseAppIndefinitely(m);

        verify(app.appPaused(true, m)).called(1);
        verify(device.setCloudEnabled(false, m)).called(1);
        verify(timer.stop(any, any)).called(1);
      });
    });

    test("unpauseApp", () async {
      await withTrace((m) async {
        final app = MockAppStore();
        Core.register<AppStore>(app);

        Core.register<PlusActor>(MockPlusActor());

        final device = MockDeviceStore();
        Core.register<DeviceStore>(device);

        final perm = MockPlatformPermActor();
        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => false);
        Core.register<PlatformPermActor>(perm);

        final account = MockAccountStore();
        when(account.type).thenAnswer((_) => AccountType.cloud);
        Core.register<AccountStore>(account);

        final timer = MockScheduler();
        Core.register<Scheduler>(timer);

        final stage = MockStageStore();
        Core.register<StageStore>(stage);

        final subject = AppStartStore();

        // No perms
        await expectLater(subject.unpauseApp(m), throwsException);
        verifyNever(device.setCloudEnabled(any, any));

        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => true);
        await subject.unpauseApp(m);

        verify(app.appPaused(false, m)).called(1);
        verify(device.setCloudEnabled(true, m)).called(1);
        verify(timer.stop(any, any)).called(1);
      });
    });

    // // Can toggle
    // await subject.toggleApp;
    // expect(subject.status, AppStatus.paused);
    // await subject.toggleApp;
    // expect(subject.status, AppStatus.activatedCloud);
    //
    // // Same for toggling
    // await subject.toggleApp;
    // expect(subject.status, AppStatus.deactivated);
  });

  group("storeErrors", () {
    test("onUnpauseAppWillShowPaymentModalOnInactiveAccount", () async {
      await withTrace((m) async {
        Core.register<Scheduler>(MockScheduler());

        final stage = MockStageStore();
        Core.register<StageStore>(stage);

        final account = MockAccountStore();
        when(account.type).thenAnswer((_) => AccountType.libre);
        Core.register<AccountStore>(account);

        final app = MockAppStore();
        Core.register<AppStore>(app);

        final perm = MockPlatformPermActor();
        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => false);
        Core.register<PlatformPermActor>(perm);

        final payment = MockPaymentActor();
        Core.register<PaymentActor>(payment);

        final subject = AppStartStore();

        await subject.unpauseApp(m);

        verify(payment.openPaymentScreen((any))).called(1);
      });
    });

    test("onUnpauseAppWillShowOnboardingOnMissingPerms", () async {
      await withTrace((m) async {
        Core.register<Scheduler>(MockScheduler());

        final stage = MockStageStore();
        Core.register<StageStore>(stage);

        final account = MockAccountStore();
        when(account.type).thenAnswer((_) => AccountType.cloud);
        Core.register<AccountStore>(account);

        final device = DeviceStore();
        Core.register<DeviceStore>(device);

        final perm = MockPlatformPermActor();
        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => false);
        Core.register<PlatformPermActor>(perm);

        final app = MockAppStore();
        Core.register<AppStore>(app);

        final subject = AppStartStore();

        await expectLater(subject.unpauseApp(m), throwsException);
      });
    });
  });
}
