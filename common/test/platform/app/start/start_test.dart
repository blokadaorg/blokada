import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/features/safari/domain/safari.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/refresh/refresh.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/start/start.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/features/plus/domain/vpn/vpn.dart';
import 'package:common/src/features/plus/domain/plus.dart';
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
  MockSpec<BlockawebPingValue>(),
])
import 'start_test.mocks.dart';

void main() {
  group("store", () {
    test("pauseAppUntil", () async {
      await withTrace((m) async {
        final app = MockAppStore();
        final conditions = AppStatusStrategy(accountIsFreemium: false);
        when(app.conditions).thenReturn(conditions);
        Core.register<AppStore>(app);

        Core.register<PlusActor>(MockPlusActor());

        final device = MockDeviceStore();
        Core.register<DeviceStore>(device);

        final timer = MockScheduler();
        Core.register<Scheduler>(timer);

        final ping = MockBlockawebPingValue();
        when(ping.isPingValidAndActive(any)).thenReturn(false);
        Core.register<BlockawebPingValue>(ping);

        final subject = AppStartStore();
        final duration = const Duration(seconds: 30);

        await subject.pauseAppUntil(duration, m);

        verify(app.appPaused(true, m)).called(1);
        verify(
          device.setCloudEnabled(m, false, pauseDuration: duration),
        ).called(1);
      });
    });

    test("pauseAppIndefinitely", () async {
      await withTrace((m) async {
        final app = MockAppStore();
        final conditions = AppStatusStrategy(accountIsFreemium: false);
        when(app.conditions).thenReturn(conditions);
        Core.register<AppStore>(app);

        Core.register<PlusActor>(MockPlusActor());

        final device = MockDeviceStore();
        Core.register<DeviceStore>(device);

        final timer = MockScheduler();
        Core.register<Scheduler>(timer);

        final ping = MockBlockawebPingValue();
        when(ping.isPingValidAndActive(any)).thenReturn(false);
        Core.register<BlockawebPingValue>(ping);

        final subject = AppStartStore();

        await subject.pauseAppIndefinitely(m);

        verify(app.appPaused(true, m)).called(1);
        verify(device.setCloudEnabled(m, false, pauseDuration: null)).called(1);
      });
    });

    test("unpauseApp", () async {
      await withTrace((m) async {
        final app = MockAppStore();
        final conditions = AppStatusStrategy(accountIsFreemium: false);
        when(app.conditions).thenReturn(conditions);
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

        final ping = MockBlockawebPingValue();
        when(ping.isPingValidAndActive(any)).thenReturn(false);
        Core.register<BlockawebPingValue>(ping);

        final subject = AppStartStore();

        // No perms
        await expectLater(subject.unpauseApp(m), throwsException);
        verifyNever(device.setCloudEnabled(any, any));

        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => true);
        await subject.unpauseApp(m);

        verify(app.appPaused(false, m)).called(1);
        verify(device.setCloudEnabled(m, true)).called(1);
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
        when(account.isFreemium).thenAnswer((_) => false); // Not freemium
        Core.register<AccountStore>(account);

        final app = MockAppStore();
        final conditions = AppStatusStrategy(accountIsFreemium: false);
        when(app.conditions).thenReturn(conditions);
        Core.register<AppStore>(app);

        final perm = MockPlatformPermActor();
        when(perm.isPrivateDnsEnabledFor(any)).thenAnswer((_) => false);
        Core.register<PlatformPermActor>(perm);

        final payment = MockPaymentActor();
        Core.register<PaymentActor>(payment);

        final ping = MockBlockawebPingValue();
        when(ping.isPingValidAndActive(any)).thenReturn(false);
        Core.register<BlockawebPingValue>(ping);

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
        final conditions = AppStatusStrategy(accountIsFreemium: false);
        when(app.conditions).thenReturn(conditions);
        Core.register<AppStore>(app);

        final ping = MockBlockawebPingValue();
        when(ping.isPingValidAndActive(any)).thenReturn(false);
        Core.register<BlockawebPingValue>(ping);

        final subject = AppStartStore();

        await expectLater(subject.unpauseApp(m), throwsException);
      });
    });

    test(
      "onUnpauseAppFreemiumWithActiveSafariExtensionShouldActivate",
      () async {
        await withTrace((m) async {
          Core.register<Scheduler>(MockScheduler());

          final stage = MockStageStore();
          Core.register<StageStore>(stage);

          final account = MockAccountStore();
          when(account.type).thenAnswer((_) => AccountType.libre);
          when(account.isFreemium).thenAnswer((_) => true);
          Core.register<AccountStore>(account);

          final device = MockDeviceStore();
          Core.register<DeviceStore>(device);

          final perm = MockPlatformPermActor();
          Core.register<PlatformPermActor>(perm);

          final app = MockAppStore();
          final conditions = AppStatusStrategy(accountIsFreemium: true);
          when(app.conditions).thenReturn(conditions);
          Core.register<AppStore>(app);

          Core.register<PlusActor>(MockPlusActor());

          final ping = MockBlockawebPingValue();
          final activePing = JsonBlockaweb(
            timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
            active: true,
            freemium: true,
          );
          when(
            ping.fetch(any, force: true),
          ).thenAnswer((_) async => activePing);
          when(ping.isPingValidAndActive(activePing)).thenReturn(true);
          Core.register<BlockawebPingValue>(ping);

          final subject = AppStartStore();

          await subject.unpauseApp(m);

          // Should activate successfully without throwing exception
          verify(app.appPaused(false, m)).called(1);
          verifyNever(device.setCloudEnabled(m, true));
        });
      },
    );

    test(
      "onUnpauseAppFreemiumWithInactiveSafariExtensionShouldShowPaywall",
      () async {
        await withTrace((m) async {
          Core.register<Scheduler>(MockScheduler());

          final stage = MockStageStore();
          Core.register<StageStore>(stage);

          final account = MockAccountStore();
          when(account.type).thenAnswer((_) => AccountType.libre);
          when(account.isFreemium).thenAnswer((_) => true);
          Core.register<AccountStore>(account);

          final app = MockAppStore();
          final conditions = AppStatusStrategy(accountIsFreemium: true);
          when(app.conditions).thenReturn(conditions);
          Core.register<AppStore>(app);

          Core.register<PlusActor>(MockPlusActor());

          final perm = MockPlatformPermActor();
          Core.register<PlatformPermActor>(perm);

          final payment = MockPaymentActor();
          Core.register<PaymentActor>(payment);

          final ping = MockBlockawebPingValue();
          final inactivePing = JsonBlockaweb(
            timestamp: DateTime.now().subtract(const Duration(days: 2)),
            active: false,
            freemium: true,
          );
          when(
            ping.fetch(any, force: true),
          ).thenAnswer((_) async => inactivePing);
          when(ping.isPingValidAndActive(inactivePing)).thenReturn(false);
          Core.register<BlockawebPingValue>(ping);

          final subject = AppStartStore();

          await subject.unpauseApp(m);

          // Should show paywall
          verify(payment.openPaymentScreen(any)).called(1);
        });
      },
    );

    test(
      "onUnpauseAppFreemiumWithNoSafariExtensionPingShouldShowPaywall",
      () async {
        await withTrace((m) async {
          Core.register<Scheduler>(MockScheduler());

          final stage = MockStageStore();
          Core.register<StageStore>(stage);

          final account = MockAccountStore();
          when(account.type).thenAnswer((_) => AccountType.libre);
          when(account.isFreemium).thenAnswer((_) => true);
          Core.register<AccountStore>(account);

          final app = MockAppStore();
          final conditions = AppStatusStrategy(accountIsFreemium: true);
          when(app.conditions).thenReturn(conditions);
          Core.register<AppStore>(app);

          Core.register<PlusActor>(MockPlusActor());

          final perm = MockPlatformPermActor();
          Core.register<PlatformPermActor>(perm);

          final payment = MockPaymentActor();
          Core.register<PaymentActor>(payment);

          final ping = MockBlockawebPingValue();
          when(ping.fetch(any, force: true)).thenAnswer((_) async => null);
          when(ping.isPingValidAndActive(null)).thenReturn(false);
          Core.register<BlockawebPingValue>(ping);

          final subject = AppStartStore();

          await subject.unpauseApp(m);

          // Should show paywall
          verify(payment.openPaymentScreen(any)).called(1);
        });
      },
    );

    test("onUnpauseAppTrueLibreUserShouldShowPaywall", () async {
      await withTrace((m) async {
        Core.register<Scheduler>(MockScheduler());

        final stage = MockStageStore();
        Core.register<StageStore>(stage);

        final account = MockAccountStore();
        when(account.type).thenAnswer((_) => AccountType.libre);
        when(account.isFreemium).thenAnswer((_) => false); // Not freemium
        Core.register<AccountStore>(account);

        final app = MockAppStore();
        final conditions = AppStatusStrategy(accountIsFreemium: false);
        when(app.conditions).thenReturn(conditions);
        Core.register<AppStore>(app);

        Core.register<PlusActor>(MockPlusActor());

        final perm = MockPlatformPermActor();
        Core.register<PlatformPermActor>(perm);

        final payment = MockPaymentActor();
        Core.register<PaymentActor>(payment);

        final ping = MockBlockawebPingValue();
        when(ping.isPingValidAndActive(any)).thenReturn(false);
        Core.register<BlockawebPingValue>(ping);

        final subject = AppStartStore();

        await subject.unpauseApp(m);

        verify(payment.openPaymentScreen(any)).called(1);
      });
    });
  });
}
