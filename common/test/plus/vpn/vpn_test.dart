import 'dart:async';

import 'package:common/app/app.dart';
import 'package:common/plus/vpn/channel.pg.dart';
import 'package:common/plus/vpn/vpn.dart';
import 'package:common/timer/timer.dart';
import 'package:common/util/config.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
@GenerateNiceMocks([
  MockSpec<TimerService>(),
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
    test("setConfigWillQueueIfNotReady", () async {
      await withTrace((trace) async {
        final ops = MockPlusVpnOps();
        depend<PlusVpnOps>(ops);

        depend<AppStore>(MockAppStore());
        depend<TimerService>(MockTimerService());

        // First call will queue up because the status is not ready
        final subject = PlusVpnStore();
        await subject.setConfig(trace, _createFixtureConfig());
        verifyNever(ops.doSetVpnConfig(any));

        // Several calls should keep only the latest config
        final newConfig = _createFixtureConfig();
        newConfig.deviceTag = "newTag";
        await subject.setConfig(trace, newConfig);
        verifyNever(ops.doSetVpnConfig(any));

        // Simulate the status coming after a while
        Timer(const Duration(milliseconds: 1), () async {
          await subject.setActualStatus(trace, "deactivated");
        });

        // Should process the queue item when ready
        await subject.setActualStatus(trace, "paused");
        // Verify the call was made with the latest config
        verify(ops.doSetVpnConfig(newConfig)).called(1);
      });
    });

    test("setConfigWillMeasureTime", () async {
      await withTrace((trace) async {
        final ops = MockPlusVpnOps();
        depend<PlusVpnOps>(ops);

        depend<AppStore>(MockAppStore());

        final timer = MockTimerService();
        depend<TimerService>(timer);

        final subject = PlusVpnStore();
        await subject.setActualStatus(trace, "deactivated");
        await subject.setConfig(trace, _createFixtureConfig());
        verify(ops.doSetVpnConfig(any)).called(1);
        verify(timer.set(any, any)).called(1);
        verify(timer.unset(any)).called(1);

        // Will unset timer even on fail
        when(ops.doSetVpnConfig(any)).thenThrow(Exception());
        await expectLater(
            subject.setConfig(trace, _createFixtureConfig(gw: "gw2")),
            throwsException);
        verify(timer.set(any, any)).called(1);
        verify(timer.unset(any)).called(1);
      });
    });

    test("setVpnActiveWillQueueWhenNotReady", () async {
      await withTrace((trace) async {
        final ops = MockPlusVpnOps();
        depend<PlusVpnOps>(ops);

        depend<AppStore>(MockAppStore());

        final timer = MockTimerService();
        depend<TimerService>(timer);

        final subject = PlusVpnStore();
        await subject.setVpnActive(trace, false);
        verifyNever(ops.doSetVpnActive(any));

        // Several calls should keep the latest config
        await subject.setVpnActive(trace, true);
        verifyNever(ops.doSetVpnActive(any));
        expect(subject.targetStatus, VpnStatus.activated);

        // Simulate the status coming after a while
        Timer(const Duration(milliseconds: 1), () async {
          await subject.setActualStatus(trace, "activated");
        });

        // Should process the queue item when ready,
        await subject.setActualStatus(trace, "deactivated");
        // Verify the call was made with the latest config
        verify(ops.doSetVpnActive(true)).called(1);
      });
    });

    test("setVpnActiveWillMeasureTime", () async {
      await withTrace((trace) async {
        final ops = MockPlusVpnOps();
        depend<PlusVpnOps>(ops);

        depend<AppStore>(MockAppStore());

        final timer = MockTimerService();
        depend<TimerService>(timer);

        final subject = PlusVpnStore();
        await subject.setActualStatus(trace, "deactivated");

        // Simulate the status coming after a while
        Timer(const Duration(milliseconds: 1), () async {
          await subject.setActualStatus(trace, "activated");
        });

        await subject.setVpnActive(trace, true);
        verify(ops.doSetVpnActive(any)).called(1);
        verify(timer.set(any, any)).called(1);
        verify(timer.unset(any)).called(1);

        // Will unset timer even on fail
        when(ops.doSetVpnActive(any)).thenThrow(Exception());
        await expectLater(subject.setVpnActive(trace, true), throwsException);
        verify(timer.set(any, any)).called(1);
        verify(timer.unset(any)).called(1);
      });
    });
  });

  group("storeErrors", () {
    test("setActiveWillErrorIfStatusIsNotReported", () async {
      await withTrace((trace) async {
        final ops = MockPlusVpnOps();
        depend<PlusVpnOps>(ops);

        final timer = DefaultTimer();
        depend<TimerService>(timer);

        final subject = PlusVpnStore();
        subject.actualStatus = VpnStatus.deactivated;
        cfg.plusVpnCommandTimeout = const Duration(seconds: 0);

        await expectLater(subject.setVpnActive(trace, true), throwsException);
      });
    });
  });
}
