import 'package:common/account/account.dart';
import 'package:common/account/refresh/refresh.dart';
import 'package:common/app/app.dart';
import 'package:common/app/start/channel.pg.dart';
import 'package:common/app/start/start.dart';
import 'package:common/device/device.dart';
import 'package:common/perm/perm.dart';
import 'package:common/plus/plus.dart';
import 'package:common/plus/vpn/vpn.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:common/stage/stage.dart';
import 'package:common/timer/timer.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
@GenerateNiceMocks([
  MockSpec<AppStore>(),
  MockSpec<TimerService>(),
  MockSpec<AppStartOps>(),
  MockSpec<AppStartStore>(),
  MockSpec<DeviceStore>(),
  MockSpec<PermStore>(),
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
        depend<AppStore>(app);

        depend<PlusStore>(MockPlusStore());

        final device = MockDeviceStore();
        depend<DeviceStore>(device);

        final timer = MockTimerService();
        depend<TimerService>(timer);

        final ops = MockAppStartOps();
        depend<AppStartOps>(ops);

        final subject = AppStartStore();
        subject.act = mockedAct;

        await subject.pauseAppUntil(const Duration(seconds: 30), m);

        verify(app.appPaused(true, m)).called(1);
        verify(device.setCloudEnabled(false, m)).called(1);
        verify(timer.set(any, any)).called(1);
      });
    });

    test("pauseAppIndefinitely", () async {
      await withTrace((m) async {
        final app = MockAppStore();
        depend<AppStore>(app);

        depend<PlusStore>(MockPlusStore());

        final device = MockDeviceStore();
        depend<DeviceStore>(device);

        final timer = MockTimerService();
        depend<TimerService>(timer);

        final ops = MockAppStartOps();
        depend<AppStartOps>(ops);

        final subject = AppStartStore();
        subject.act = mockedAct;

        await subject.pauseAppIndefinitely(m);

        verify(app.appPaused(true, m)).called(1);
        verify(device.setCloudEnabled(false, m)).called(1);
        verify(timer.unset(any)).called(1);
      });
    });

    test("unpauseApp", () async {
      await withTrace((m) async {
        final app = MockAppStore();
        depend<AppStore>(app);

        depend<PlusStore>(MockPlusStore());

        final device = MockDeviceStore();
        depend<DeviceStore>(device);

        final perm = MockPermStore();
        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => false);
        depend<PermStore>(perm);

        final account = MockAccountStore();
        when(account.type).thenAnswer((_) => AccountType.cloud);
        depend<AccountStore>(account);

        final timer = MockTimerService();
        depend<TimerService>(timer);

        final stage = MockStageStore();
        depend<StageStore>(stage);

        final ops = MockAppStartOps();
        depend<AppStartOps>(ops);

        final subject = AppStartStore();
        subject.act = mockedAct;

        // No perms
        await subject.unpauseApp(m);
        verifyNever(device.setCloudEnabled(any, any));

        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => true);
        await subject.unpauseApp(m);

        verify(app.appPaused(false, m)).called(1);
        verify(device.setCloudEnabled(true, m)).called(1);
        verify(timer.unset(any)).called(1);
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
        depend<TimerService>(MockTimerService());

        final ops = MockAppStartOps();
        depend<AppStartOps>(ops);

        final stage = MockStageStore();
        depend<StageStore>(stage);

        final account = MockAccountStore();
        when(account.type).thenAnswer((_) => AccountType.libre);
        depend<AccountStore>(account);

        final app = MockAppStore();
        depend<AppStore>(app);

        final subject = AppStartStore();

        await subject.unpauseApp(m);

        verify(stage.showModal(StageModal.payment, m)).called(1);
      });
    });

    test("onUnpauseAppWillShowOnboardingOnMissingPerms", () async {
      await withTrace((m) async {
        depend<TimerService>(MockTimerService());

        final ops = MockAppStartOps();
        depend<AppStartOps>(ops);

        final stage = MockStageStore();
        depend<StageStore>(stage);

        final account = MockAccountStore();
        when(account.type).thenAnswer((_) => AccountType.cloud);
        depend<AccountStore>(account);

        final device = DeviceStore();
        depend<DeviceStore>(device);

        final perm = MockPermStore();
        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => false);
        depend<PermStore>(perm);

        final app = MockAppStore();
        depend<AppStore>(app);

        final subject = AppStartStore();

        await subject.unpauseApp(m);

        verify(stage.showModal(StageModal.perms, m)).called(1);
      });
    });
  });
}
