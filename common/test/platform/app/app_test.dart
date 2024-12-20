import 'dart:convert';

import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/account/json.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/app/channel.pg.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/perm/perm.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
import '../account/fixtures.dart';
@GenerateNiceMocks([
  MockSpec<AppStore>(),
  MockSpec<AppOps>(),
  MockSpec<DeviceStore>(),
  MockSpec<AccountStore>(),
  MockSpec<StageStore>(),
])
import 'app_test.mocks.dart';

void main() {
  group("store", () {
    test("willHandleInitProcedure", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());
        Core.register<AccountStore>(MockAccountStore());
        Core.register<DeviceStore>(MockDeviceStore());
        Core.register<AppOps>(MockAppOps());

        final subject = AppStore();

        expect(subject.status, AppStatus.unknown);

        await subject.initStarted(m);
        expect(subject.status, AppStatus.initializing);

        await subject.initCompleted(m);
        expect(subject.status, AppStatus.deactivated);
      });
    });

    test("willHandleCloudEnabled", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());
        Core.register<AppOps>(MockAppOps());

        final device = MockDeviceStore();
        when(device.cloudEnabled).thenReturn(true);
        Core.register<DeviceStore>(device);

        final account = MockAccountStore();
        when(account.account).thenReturn(AccountState(
          "mockedmocked",
          JsonAccount.fromJson(jsonDecode(fixtureJsonAccount)),
        ));
        Core.register<AccountStore>(account);

        final subject = AppStore();

        // Initially the app is deactivated
        await subject.initStarted(m);
        await subject.initCompleted(m);
        expect(subject.status, AppStatus.deactivated);

        // User got a Cloud account, still deactivated
        await subject.onAccountChanged(m);
        expect(subject.status, AppStatus.deactivated);

        // Granted perms and enabled Cloud in api, now should be active
        await subject.cloudPermEnabled(true, m);
        await subject.onDeviceChanged(m);
        expect(subject.status, AppStatus.activatedCloud);

        // Rejected perms again
        await subject.cloudPermEnabled(false, m);
        expect(subject.status, AppStatus.deactivated);
      });
    });

    test("willHandlePause", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());
        Core.register<AppOps>(MockAppOps());

        final device = MockDeviceStore();
        when(device.cloudEnabled).thenReturn(true);
        Core.register<DeviceStore>(device);

        final account = MockAccountStore();
        when(account.account).thenReturn(AccountState(
          "mockedmocked",
          JsonAccount.fromJson(jsonDecode(fixtureJsonAccount)),
        ));
        Core.register<AccountStore>(account);

        final subject = AppStore();

        // Initially the app is deactivated
        await subject.initStarted(m);
        await subject.initCompleted(m);
        expect(subject.status, AppStatus.deactivated);

        // User got the onboarding right for device
        await subject.onAccountChanged(m);
        await subject.cloudPermEnabled(true, m);
        await subject.onDeviceChanged(m);
        expect(subject.status, AppStatus.activatedCloud);

        // Can pause, unpause
        await subject.appPaused(true, m);
        expect(subject.status, AppStatus.deactivated);
        await subject.appPaused(false, m);
        expect(subject.status, AppStatus.activatedCloud);

        // When the requirements are not satisfied, wont unpause
        await subject.cloudPermEnabled(false, m);
        await subject.appPaused(true, m);
        expect(subject.status, AppStatus.deactivated);
        await subject.appPaused(false, m);
        expect(subject.status, AppStatus.deactivated);
      });
    });
  });

  group("storeErrors", () {
    test("initWillFailOnImproperStates", () async {
      await withTrace((m) async {
        Core.register<AccountStore>(MockAccountStore());
        Core.register<DeviceStore>(MockDeviceStore());
        Core.register<StageStore>(MockStageStore());
        Core.register<AppOps>(MockAppOps());

        final subject = AppStore();

        // Can't complete init before starting
        await expectLater(subject.initCompleted(m), throwsStateError);

        // Can't init twice
        await subject.initStarted(m);
        await expectLater(subject.initStarted(m), throwsStateError);

        // Can't complete init twice
        await subject.initCompleted(m);
        await expectLater(subject.initCompleted(m), throwsStateError);
      });
    });
  });

  group("binder", () {
    test("onCloudPermStatus", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final store = MockAppStore();
        Core.register<AppStore>(store);

        Core.register(PrivateDnsEnabledFor());

        final perm = PlatformPermActor();
        Core.register<PlatformPermActor>(perm);

        final device = MockDeviceStore();
        when(device.deviceTag).thenReturn("some-tag");
        Core.register<DeviceStore>(device);

        final account = MockAccountStore();
        Core.register<AccountStore>(account);

        verifyNever(store.cloudPermEnabled(any, any));

        await perm.setPrivateDnsEnabled("some-tag", m);

        verify(store.cloudPermEnabled(true, m)).called(1);
      });
    });
  });
}
