import 'package:common/account/account.dart';
import 'package:common/account/refresh/refresh.dart';
import 'package:common/app/app.dart';
import 'package:common/app/pause/channel.pg.dart';
import 'package:common/app/pause/pause.dart';
import 'package:common/device/device.dart';
import 'package:common/perm/perm.dart';
import 'package:common/plus/vpn/vpn.dart';
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
  MockSpec<AppPauseOps>(),
  MockSpec<AppPauseStore>(),
  MockSpec<DeviceStore>(),
  MockSpec<PermStore>(),
  MockSpec<AccountStore>(),
  MockSpec<StageStore>(),
  MockSpec<AccountRefreshStore>(),
  MockSpec<PlusVpnStore>(),
])
import 'pause_test.mocks.dart';

void main() {
  group("store", () {
    test("pauseAppUntil", () async {
      await withTrace((trace) async {
        final app = MockAppStore();
        di.registerSingleton<AppStore>(app);

        final device = MockDeviceStore();
        di.registerSingleton<DeviceStore>(device);

        final timer = MockTimerService();
        di.registerSingleton<TimerService>(timer);

        final ops = MockAppPauseOps();
        depend<AppPauseOps>(ops);

        final subject = AppPauseStore();

        await subject.pauseAppUntil(trace, const Duration(seconds: 30));

        verify(app.appPaused(any, true)).called(1);
        verify(device.setCloudEnabled(any, false)).called(1);
        verify(timer.set(any, any)).called(1);
      });
    });

    test("pauseAppIndefinitely", () async {
      await withTrace((trace) async {
        final app = MockAppStore();
        di.registerSingleton<AppStore>(app);

        final device = MockDeviceStore();
        di.registerSingleton<DeviceStore>(device);

        final timer = MockTimerService();
        di.registerSingleton<TimerService>(timer);

        final ops = MockAppPauseOps();
        depend<AppPauseOps>(ops);

        final subject = AppPauseStore();

        await subject.pauseAppIndefinitely(trace);

        verify(app.appPaused(any, true)).called(1);
        verify(device.setCloudEnabled(any, false)).called(1);
        verify(timer.unset(any)).called(1);
      });
    });

    test("unpauseApp", () async {
      await withTrace((trace) async {
        final app = MockAppStore();
        di.registerSingleton<AppStore>(app);

        final device = MockDeviceStore();
        di.registerSingleton<DeviceStore>(device);

        final perm = MockPermStore();
        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => false);
        di.registerSingleton<PermStore>(perm);

        final account = MockAccountStore();
        when(account.getAccountType()).thenAnswer((_) => AccountType.cloud);
        di.registerSingleton<AccountStore>(account);

        final timer = MockTimerService();
        di.registerSingleton<TimerService>(timer);

        final stage = MockStageStore();
        di.registerSingleton<StageStore>(stage);

        final ops = MockAppPauseOps();
        depend<AppPauseOps>(ops);

        final subject = AppPauseStore();

        // No perms
        await subject.unpauseApp(trace);
        verifyNever(device.setCloudEnabled(any, any));

        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => true);
        await subject.unpauseApp(trace);

        verify(app.appPaused(any, false)).called(1);
        verify(device.setCloudEnabled(any, true)).called(1);
        verify(timer.unset(any)).called(1);
      });
    });

    // // Can toggle
    // await subject.toggleApp(trace);
    // expect(subject.status, AppStatus.paused);
    // await subject.toggleApp(trace);
    // expect(subject.status, AppStatus.activatedCloud);
    //
    // // Same for toggling
    // await subject.toggleApp(trace);
    // expect(subject.status, AppStatus.deactivated);
  });

  group("storeErrors", () {
    test("onUnpauseAppWillShowPaymentModalOnInactiveAccount", () async {
      await withTrace((trace) async {
        di.registerSingleton<TimerService>(MockTimerService());

        final ops = MockAppPauseOps();
        di.registerSingleton<AppPauseOps>(ops);

        final stage = MockStageStore();
        di.registerSingleton<StageStore>(stage);

        final account = MockAccountStore();
        when(account.getAccountType()).thenAnswer((_) => AccountType.libre);
        di.registerSingleton<AccountStore>(account);

        final app = MockAppStore();
        di.registerSingleton<AppStore>(app);

        final subject = AppPauseStore();

        await subject.unpauseApp(trace);

        verify(stage.showModalNow(any, StageModal.payment)).called(1);
      });
    });

    test("onUnpauseAppWillShowOnboardingOnMissingPerms", () async {
      await withTrace((trace) async {
        di.registerSingleton<TimerService>(MockTimerService());

        final ops = MockAppPauseOps();
        di.registerSingleton<AppPauseOps>(ops);

        final stage = MockStageStore();
        di.registerSingleton<StageStore>(stage);

        final account = MockAccountStore();
        when(account.getAccountType()).thenAnswer((_) => AccountType.cloud);
        di.registerSingleton<AccountStore>(account);

        final device = DeviceStore();
        di.registerSingleton<DeviceStore>(device);

        final perm = MockPermStore();
        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => false);
        di.registerSingleton<PermStore>(perm);

        final app = MockAppStore();
        di.registerSingleton<AppStore>(app);

        final subject = AppPauseStore();

        await subject.unpauseApp(trace);

        verify(stage.showModalNow(any, StageModal.onboarding)).called(1);
      });
    });
  });
}
