import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/account/refresh/refresh.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/app/start/channel.pg.dart';
import 'package:common/platform/app/start/start.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/perm/perm.dart';
import 'package:common/platform/plus/plus.dart';
import 'package:common/platform/plus/vpn/vpn.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';
@GenerateNiceMocks([
  MockSpec<AppStore>(),
  MockSpec<Scheduler>(),
  MockSpec<AppStartOps>(),
  MockSpec<AppStartStore>(),
  MockSpec<DeviceStore>(),
  MockSpec<PlatformPermActor>(),
  MockSpec<AccountStore>(),
  MockSpec<StageStore>(),
  MockSpec<AccountRefreshStore>(),
  MockSpec<PlusVpnStore>(),
  MockSpec<PlusStore>(),
])
import 'start_test.mocks.dart';

void main() {
  group("store", () {
    test("pauseAppUntil", () async {
      await withTrace((m) async {
        final app = MockAppStore();
        DI.register<AppStore>(app);

        DI.register<PlusStore>(MockPlusStore());

        final device = MockDeviceStore();
        DI.register<DeviceStore>(device);

        final timer = MockScheduler();
        DI.register<Scheduler>(timer);

        final ops = MockAppStartOps();
        DI.register<AppStartOps>(ops);

        final subject = AppStartStore();
        subject.act = mockedAct;

        await subject.pauseAppUntil(const Duration(seconds: 30), m);

        verify(app.appPaused(true, m)).called(1);
        verify(device.setCloudEnabled(false, m)).called(1);
        verify(timer.addOrUpdate(any)).called(1);
      });
    });

    test("pauseAppIndefinitely", () async {
      await withTrace((m) async {
        final app = MockAppStore();
        DI.register<AppStore>(app);

        DI.register<PlusStore>(MockPlusStore());

        final device = MockDeviceStore();
        DI.register<DeviceStore>(device);

        final timer = MockScheduler();
        DI.register<Scheduler>(timer);

        final ops = MockAppStartOps();
        DI.register<AppStartOps>(ops);

        final subject = AppStartStore();
        subject.act = mockedAct;

        await subject.pauseAppIndefinitely(m);

        verify(app.appPaused(true, m)).called(1);
        verify(device.setCloudEnabled(false, m)).called(1);
        verify(timer.stop(any, any)).called(1);
      });
    });

    test("unpauseApp", () async {
      await withTrace((m) async {
        final app = MockAppStore();
        DI.register<AppStore>(app);

        DI.register<PlusStore>(MockPlusStore());

        final device = MockDeviceStore();
        DI.register<DeviceStore>(device);

        final perm = MockPlatformPermActor();
        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => false);
        DI.register<PlatformPermActor>(perm);

        final account = MockAccountStore();
        when(account.type).thenAnswer((_) => AccountType.cloud);
        DI.register<AccountStore>(account);

        final timer = MockScheduler();
        DI.register<Scheduler>(timer);

        final stage = MockStageStore();
        DI.register<StageStore>(stage);

        final ops = MockAppStartOps();
        DI.register<AppStartOps>(ops);

        final subject = AppStartStore();
        subject.act = mockedAct;

        // No perms
        await subject.unpauseApp(m);
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
        DI.register<Scheduler>(MockScheduler());

        final ops = MockAppStartOps();
        DI.register<AppStartOps>(ops);

        final stage = MockStageStore();
        DI.register<StageStore>(stage);

        final account = MockAccountStore();
        when(account.type).thenAnswer((_) => AccountType.libre);
        DI.register<AccountStore>(account);

        final app = MockAppStore();
        DI.register<AppStore>(app);

        final subject = AppStartStore();

        await subject.unpauseApp(m);

        verify(stage.showModal(StageModal.payment, m)).called(1);
      });
    });

    test("onUnpauseAppWillShowOnboardingOnMissingPerms", () async {
      await withTrace((m) async {
        DI.register<Scheduler>(MockScheduler());

        final ops = MockAppStartOps();
        DI.register<AppStartOps>(ops);

        final stage = MockStageStore();
        DI.register<StageStore>(stage);

        final account = MockAccountStore();
        when(account.type).thenAnswer((_) => AccountType.cloud);
        DI.register<AccountStore>(account);

        final device = DeviceStore();
        DI.register<DeviceStore>(device);

        final perm = MockPlatformPermActor();
        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => false);
        DI.register<PlatformPermActor>(perm);

        final app = MockAppStore();
        DI.register<AppStore>(app);

        final subject = AppStartStore();

        await subject.unpauseApp(m);

        verify(stage.showModal(StageModal.perms, m)).called(1);
      });
    });
  });
}
