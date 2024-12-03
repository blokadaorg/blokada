import 'dart:async';

import 'package:common/core/core.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/plus/vpn/channel.pg.dart';
import 'package:common/platform/plus/vpn/vpn.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';
@GenerateNiceMocks([
  MockSpec<Scheduler>(),
  MockSpec<PlusVpnOps>(),
  MockSpec<PlusVpnStore>(),
  MockSpec<AppStore>(),
])
import 'vpn_test.mocks.dart';

_createFixtureConfig({String gw = "gw"}) => VpnConfig(
      devicePrivateKey: "pk",
      deviceTag: "tag",
      gatewayPublicKey: gw,
      gatewayNiceName: "gateway",
      gatewayIpv4: "ipv4",
      gatewayIpv6: "ipv6",
      gatewayPort: "69",
      leaseVip4: "vip4",
      leaseVip6: "vip6",
    );

void main() {
  group("store", () {
    test("setVpnConfigWillQueueIfNotReady", () async {
      await withTrace((m) async {
        final ops = MockPlusVpnOps();
        Core.register<PlusVpnOps>(ops);

        Core.register<AppStore>(MockAppStore());
        Core.register<Scheduler>(MockScheduler());

        // First call will queue up because the status is not ready
        final subject = PlusVpnStore();
        await subject.setVpnConfig(_createFixtureConfig(), m);
        verifyNever(ops.doSetVpnConfig(any));

        // Several calls should keep only the latest config
        final newConfig = _createFixtureConfig();
        newConfig.deviceTag = "newTag";
        await subject.setVpnConfig(newConfig, m);
        verifyNever(ops.doSetVpnConfig(any));

        // Simulate the status coming after a while
        Timer(const Duration(milliseconds: 1), () async {
          await subject.setActualStatus("deactivated", m);
        });

        // Should process the queue item when ready
        await subject.setActualStatus("paused", m);
        // Verify the call was made with the latest config
        verify(ops.doSetVpnConfig(newConfig)).called(1);
      });
    });

    test("setVpnActiveWillQueueWhenNotReady", () async {
      await withTrace((m) async {
        final ops = MockPlusVpnOps();
        Core.register<PlusVpnOps>(ops);

        Core.register<AppStore>(MockAppStore());

        final timer = MockScheduler();
        Core.register<Scheduler>(timer);

        final subject = PlusVpnStore();
        await subject.turnVpnOff(m);
        verifyNever(ops.doSetVpnActive(any));

        // Several calls should keep the latest config
        await subject.turnVpnOn(m);
        verifyNever(ops.doSetVpnActive(any));
        expect(subject.targetStatus, VpnStatus.activated);

        // Simulate the status coming after a while
        Timer(const Duration(milliseconds: 1), () async {
          await subject.setActualStatus("activated", m);
        });

        // Should process the queue item when ready,
        await subject.setActualStatus("deactivated", m);
        // Verify the call was made with the latest config
        verify(ops.doSetVpnActive(true)).called(1);
      });
    });

    test("setVpnActiveWillMeasureTime", () async {
      await withTrace((m) async {
        final ops = MockPlusVpnOps();
        Core.register<PlusVpnOps>(ops);

        Core.register<AppStore>(MockAppStore());

        final timer = MockScheduler();
        Core.register<Scheduler>(timer);

        final subject = PlusVpnStore();
        await subject.setActualStatus("deactivated", m);

        // Simulate the status coming after a while
        Timer(const Duration(milliseconds: 1), () async {
          await subject.setActualStatus("activated", m);
        });

        await subject.turnVpnOn(m);
        verify(ops.doSetVpnActive(any)).called(1);
        verify(timer.addOrUpdate(any)).called(1);
        verify(timer.stop(any, any)).called(greaterThanOrEqualTo(1));

        // Simulate the status coming after a while
        Timer(const Duration(milliseconds: 1), () async {
          await subject.setActualStatus("deactivated", m);
        });
        await subject.turnVpnOff(m);
        verify(timer.addOrUpdate(any)).called(1);
        verify(timer.stop(any, any)).called(greaterThanOrEqualTo(1));

        // Will unset timer even on fail
        when(ops.doSetVpnActive(any)).thenThrow(Exception());
        await expectLater(subject.turnVpnOn(m), throwsException);
        verify(timer.addOrUpdate(any)).called(1);
        verify(timer.stop(any, any)).called(greaterThanOrEqualTo(1));
      });
    });
  });

  group("storeErrors", () {
    test("setActiveWillErrorIfStatusIsNotReported", () async {
      await withTrace((m) async {
        final ops = MockPlusVpnOps();
        Core.register<PlusVpnOps>(ops);

        final timer = Scheduler(timer: SchedulerTimer());
        Core.register<Scheduler>(timer);

        final subject = PlusVpnStore();
        subject.actualStatus = VpnStatus.deactivated;
        Core.config.plusVpnCommandTimeout = const Duration(seconds: 0);

        await expectLater(subject.turnVpnOn(m), throwsException);
      });
    });
  });
}
