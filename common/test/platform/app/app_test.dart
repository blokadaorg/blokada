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
        DI.register<StageStore>(MockStageStore());
        DI.register<AccountStore>(MockAccountStore());
        DI.register<DeviceStore>(MockDeviceStore());

        final ops = MockAppOps();
        DI.register<AppOps>(ops);

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
        DI.register<StageStore>(MockStageStore());

        final ops = MockAppOps();
        DI.register<AppOps>(ops);

        final device = MockDeviceStore();
        when(device.cloudEnabled).thenReturn(true);
        DI.register<DeviceStore>(device);

        final account = MockAccountStore();
        when(account.account).thenReturn(AccountState(
          "mockedmocked",
          JsonAccount.fromJson(jsonDecode(fixtureJsonAccount)),
        ));
        DI.register<AccountStore>(account);

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
        DI.register<StageStore>(MockStageStore());

        final ops = MockAppOps();
        DI.register<AppOps>(ops);

        final device = MockDeviceStore();
        when(device.cloudEnabled).thenReturn(true);
        DI.register<DeviceStore>(device);

        final account = MockAccountStore();
        when(account.account).thenReturn(AccountState(
          "mockedmocked",
          JsonAccount.fromJson(jsonDecode(fixtureJsonAccount)),
        ));
        DI.register<AccountStore>(account);

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
        DI.register<AccountStore>(MockAccountStore());
        DI.register<DeviceStore>(MockDeviceStore());
        DI.register<StageStore>(MockStageStore());

        final ops = MockAppOps();
        DI.register<AppOps>(ops);

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
    test("onAppStatus", () async {
      await withTrace((m) async {
        DI.register<AccountStore>(MockAccountStore());
        DI.register<DeviceStore>(MockDeviceStore());

        final ops = MockAppOps();
        DI.register<AppOps>(ops);

        final stage = MockStageStore();
        DI.register<StageStore>(stage);

        final perm = PlatformPermActor();
        DI.register<PlatformPermActor>(perm);

        final store = AppStore();
        DI.register<AppStore>(store);

        verifyNever(ops.doAppStatusChanged(any));
        await store.initStarted(m);
        await store.initCompleted(m);
        verify(ops.doAppStatusChanged(any)).called(2);
      });
    });

    test("onCloudPermStatus", () async {
      await withTrace((m) async {
        DI.register<StageStore>(MockStageStore());

        final ops = MockAppOps();
        DI.register<AppOps>(ops);

        final store = MockAppStore();
        DI.register<AppStore>(store);

        DI.register(PrivateDnsEnabledFor());

        final perm = PlatformPermActor();
        DI.register<PlatformPermActor>(perm);

        final device = MockDeviceStore();
        when(device.deviceTag).thenReturn("some-tag");
        DI.register<DeviceStore>(device);

        final account = MockAccountStore();
        DI.register<AccountStore>(account);

        verifyNever(store.cloudPermEnabled(any, any));

        perm.setPrivateDnsEnabled("some-tag", m);

        verify(store.cloudPermEnabled(true, m)).called(1);
      });
    });
  });
}
