import 'package:common/account/account.dart';
import 'package:common/app/app.dart';
import 'package:common/app/channel.pg.dart';
import 'package:common/device/device.dart';
import 'package:common/event.dart';
import 'package:common/perm/perm.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<EventBus>(),
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
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final ops = MockAppOps();
        depend<AppOps>(ops);

        final subject = AppStore();

        expect(subject.status, AppStatus.unknown);

        await subject.initStarted(trace);
        expect(subject.status, AppStatus.initializing);

        await subject.initCompleted(trace);
        expect(subject.status, AppStatus.deactivated);
      });
    });

    test("willHandleCloudEnabled", () async {
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final ops = MockAppOps();
        depend<AppOps>(ops);

        final subject = AppStore();

        // Initially the app is deactivated
        await subject.initStarted(trace);
        await subject.initCompleted(trace);
        expect(subject.status, AppStatus.deactivated);

        // User got a Cloud account, still deactivated
        await subject.accountUpdated(trace, isCloud: true, isPlus: false);
        expect(subject.status, AppStatus.deactivated);

        // Granted perms and enabled Cloud in api, now should be active
        await subject.cloudPermEnabled(trace, true);
        await subject.cloudEnabled(trace, true);
        expect(subject.status, AppStatus.activatedCloud);

        // Rejected perms again
        await subject.cloudPermEnabled(trace, false);
        expect(subject.status, AppStatus.deactivated);
      });
    });

    test("willHandlePause", () async {
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final ops = MockAppOps();
        depend<AppOps>(ops);

        final subject = AppStore();

        // Initially the app is deactivated
        await subject.initStarted(trace);
        await subject.initCompleted(trace);
        expect(subject.status, AppStatus.deactivated);

        // User got the onboarding right for device
        await subject.accountUpdated(trace, isCloud: true, isPlus: false);
        await subject.cloudPermEnabled(trace, true);
        await subject.cloudEnabled(trace, true);
        expect(subject.status, AppStatus.activatedCloud);

        // Can pause, unpause
        await subject.appPaused(trace, true);
        expect(subject.status, AppStatus.paused);
        await subject.appPaused(trace, false);
        expect(subject.status, AppStatus.activatedCloud);

        // When the requirements are not satisfied, wont unpause
        await subject.cloudPermEnabled(trace, false);
        await subject.appPaused(trace, true);
        expect(subject.status, AppStatus.deactivated);
        await subject.appPaused(trace, false);
        expect(subject.status, AppStatus.deactivated);
      });
    });
  });

  group("storeErrors", () {
    test("initWillFailOnImproperStates", () async {
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final ops = MockAppOps();
        depend<AppOps>(ops);

        final subject = AppStore();

        // Can't complete init before starting
        await expectLater(subject.initCompleted(trace), throwsStateError);

        // Can't init twice
        await subject.initStarted(trace);
        await expectLater(subject.initStarted(trace), throwsStateError);

        // Can't complete init twice
        await subject.initCompleted(trace);
        await expectLater(subject.initCompleted(trace), throwsStateError);
      });
    });
  });

  group("binder", () {
    test("onAppStatus", () async {
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final ops = MockAppOps();
        depend<AppOps>(ops);

        final store = AppStore();
        di.registerSingleton<AppStore>(store);

        final stage = MockStageStore();
        di.registerSingleton<StageStore>(stage);

        final device = MockDeviceStore();
        di.registerSingleton<DeviceStore>(device);

        final account = MockAccountStore();
        di.registerSingleton<AccountStore>(account);

        final perm = PermStore();
        di.registerSingleton<PermStore>(perm);

        verifyNever(ops.doAppStatusChanged(any));
        await store.initStarted(trace);
        await store.initCompleted(trace);
        verify(ops.doAppStatusChanged(any)).called(2);
      });
    });

    test("onCloudPermStatus", () async {
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final ops = MockAppOps();
        depend<AppOps>(ops);

        final store = MockAppStore();
        di.registerSingleton<AppStore>(store);

        final perm = PermStore();
        di.registerSingleton<PermStore>(perm);

        final device = MockDeviceStore();
        when(device.deviceTag).thenReturn("some-tag");
        di.registerSingleton<DeviceStore>(device);

        final account = MockAccountStore();
        di.registerSingleton<AccountStore>(account);

        verifyNever(store.cloudPermEnabled(any, any));

        perm.setPrivateDnsEnabled(trace, "some-tag");

        verify(store.cloudPermEnabled(any, true)).called(1);
      });
    });
  });
}
