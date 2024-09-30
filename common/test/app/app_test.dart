import 'dart:convert';

import 'package:common/account/account.dart';
import 'package:common/account/json.dart';
import 'package:common/app/app.dart';
import 'package:common/app/channel.pg.dart';
import 'package:common/device/device.dart';
import 'package:common/perm/perm.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../account/fixtures.dart';
import '../tools.dart';
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
        depend<StageStore>(MockStageStore());
        depend<AccountStore>(MockAccountStore());
        depend<DeviceStore>(MockDeviceStore());

        final ops = MockAppOps();
        depend<AppOps>(ops);

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
        depend<StageStore>(MockStageStore());

        final ops = MockAppOps();
        depend<AppOps>(ops);

        final device = MockDeviceStore();
        when(device.cloudEnabled).thenReturn(true);
        depend<DeviceStore>(device);

        final account = MockAccountStore();
        when(account.account).thenReturn(AccountState(
          "mockedmocked",
          JsonAccount.fromJson(jsonDecode(fixtureJsonAccount)),
        ));
        depend<AccountStore>(account);

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
        depend<StageStore>(MockStageStore());

        final ops = MockAppOps();
        depend<AppOps>(ops);

        final device = MockDeviceStore();
        when(device.cloudEnabled).thenReturn(true);
        depend<DeviceStore>(device);

        final account = MockAccountStore();
        when(account.account).thenReturn(AccountState(
          "mockedmocked",
          JsonAccount.fromJson(jsonDecode(fixtureJsonAccount)),
        ));
        depend<AccountStore>(account);

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
        depend<AccountStore>(MockAccountStore());
        depend<DeviceStore>(MockDeviceStore());
        depend<StageStore>(MockStageStore());

        final ops = MockAppOps();
        depend<AppOps>(ops);

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
        depend<AccountStore>(MockAccountStore());
        depend<DeviceStore>(MockDeviceStore());

        final ops = MockAppOps();
        depend<AppOps>(ops);

        final stage = MockStageStore();
        depend<StageStore>(stage);

        final perm = PermStore();
        depend<PermStore>(perm);

        final store = AppStore();
        depend<AppStore>(store);

        verifyNever(ops.doAppStatusChanged(any));
        await store.initStarted(m);
        await store.initCompleted(m);
        verify(ops.doAppStatusChanged(any)).called(2);
      });
    });

    test("onCloudPermStatus", () async {
      await withTrace((m) async {
        depend<StageStore>(MockStageStore());

        final ops = MockAppOps();
        depend<AppOps>(ops);

        final store = MockAppStore();
        depend<AppStore>(store);

        final perm = PermStore();
        depend<PermStore>(perm);

        final device = MockDeviceStore();
        when(device.deviceTag).thenReturn("some-tag");
        depend<DeviceStore>(device);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        verifyNever(store.cloudPermEnabled(any, any));

        perm.setPrivateDnsEnabled("some-tag", m);

        verify(store.cloudPermEnabled(true, m)).called(1);
      });
    });
  });
}
