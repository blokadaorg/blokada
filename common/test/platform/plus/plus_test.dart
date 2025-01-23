import 'package:common/common/module/env/env.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/plus/channel.pg.dart';
import 'package:common/platform/plus/gateway/gateway.dart';
import 'package:common/platform/plus/keypair/keypair.dart';
import 'package:common/platform/plus/lease/lease.dart';
import 'package:common/platform/plus/plus.dart';
import 'package:common/platform/plus/vpn/vpn.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
import 'fixtures.dart';
import 'gateway/fixtures.dart';
import 'lease/fixtures.dart';
@GenerateNiceMocks([
  MockSpec<PlusLeaseStore>(),
  MockSpec<PlusVpnStore>(),
  MockSpec<PlusKeypairStore>(),
  MockSpec<PlusGatewayStore>(),
  MockSpec<PlusStore>(),
  MockSpec<Persistence>(),
  MockSpec<PlusOps>(),
  MockSpec<AppStore>(),
  MockSpec<EnvActor>(),
  MockSpec<DeviceStore>(),
  MockSpec<StageStore>(),
])
import 'plus_test.mocks.dart';

void main() {
  group("store", () {
    test("load", () async {
      await withTrace((m) async {
        final ops = MockPlusOps();
        Core.register<PlusOps>(ops);

        Core.register<AppStore>(MockAppStore());

        final persistence = MockPersistence();
        when(persistence.load(any, any)).thenAnswer((_) => Future.value("1"));
        Core.register<Persistence>(persistence);

        final subject = PlusStore();
        expect(subject.plusEnabled, false);

        await subject.load(m);
        expect(subject.plusEnabled, true);
      });
    });

    test("newPlus", () async {
      await withTrace((m) async {
        final device = MockDeviceStore();
        when(device.currentDeviceTag).thenReturn("some device tag");
        Core.register<DeviceStore>(device);

        final ops = MockPlusOps();
        Core.register<PlusOps>(ops);

        final gateway = MockPlusGatewayStore();
        when(gateway.currentGateway)
            .thenReturn(fixtureGatewayEntries.first.toGateway);
        Core.register<PlusGatewayStore>(gateway);

        final keypair = MockPlusKeypairStore();
        when(keypair.currentKeypair).thenReturn(Fixtures.keypair);
        Core.register<PlusKeypairStore>(keypair);

        final app = MockAppStore();
        Core.register<AppStore>(app);

        final lease = MockPlusLeaseStore();
        when(lease.currentLease).thenReturn(fixtureLeaseEntries.first.toLease);
        Core.register<PlusLeaseStore>(lease);

        final vpn = MockPlusVpnStore();
        Core.register<PlusVpnStore>(vpn);

        final persistence = MockPersistence();
        Core.register<Persistence>(persistence);

        final subject = PlusStore();

        await subject.newPlus("some gateway id", m);
        verify(app.reconfiguring(any)).called(1);
        verify(lease.newLease("some gateway id", m)).called(1);
        verify(vpn.turnVpnOn(any)).called(1);
        verify(lease.fetch(any, noRetry: true)).called(1);
        verify(persistence.save(any, any, any));
      });
    });

    test('clearPlus', () async {
      await withTrace((m) async {
        final ops = MockPlusOps();
        Core.register<PlusOps>(ops);

        final app = MockAppStore();
        Core.register<AppStore>(app);

        final lease = MockPlusLeaseStore();
        when(lease.currentLease).thenReturn(fixtureLeaseEntries.first.toLease);
        Core.register<PlusLeaseStore>(lease);

        final vpn = MockPlusVpnStore();
        Core.register<PlusVpnStore>(vpn);

        final persistence = MockPersistence();
        Core.register<Persistence>(persistence);

        final subject = PlusStore();

        await subject.clearPlus(m);
        verify(lease.deleteLease(any, any)).called(1);
        verify(vpn.turnVpnOff(any)).called(1);
        verify(persistence.save(any, any, any));
      });
    });

    test("switchPlus", () async {
      await withTrace((m) async {
        final device = MockDeviceStore();
        when(device.currentDeviceTag).thenReturn("some device tag");
        Core.register<DeviceStore>(device);

        final gateway = MockPlusGatewayStore();
        when(gateway.currentGateway)
            .thenReturn(fixtureGatewayEntries.first.toGateway);
        Core.register<PlusGatewayStore>(gateway);

        final keypair = MockPlusKeypairStore();
        when(keypair.currentKeypair).thenReturn(Fixtures.keypair);
        Core.register<PlusKeypairStore>(keypair);

        final ops = MockPlusOps();
        Core.register<PlusOps>(ops);

        final app = MockAppStore();
        Core.register<AppStore>(app);

        final lease = MockPlusLeaseStore();
        when(lease.currentLease).thenReturn(fixtureLeaseEntries.first.toLease);
        Core.register<PlusLeaseStore>(lease);

        final vpn = MockPlusVpnStore();
        Core.register<PlusVpnStore>(vpn);

        final persistence = MockPersistence();
        Core.register<Persistence>(persistence);

        final subject = PlusStore();

        await subject.switchPlus(true, m);
        verify(vpn.turnVpnOn(any)).called(1);
        verify(lease.fetch(any, noRetry: true));
      });
    });

    // test("reactToAppStatus", () async {
    //   await withTrace((m) async {
    //     final ops = MockPlusOps();
    //     DI.register<PlusOps>(ops);
    //
    //     final app = MockAppStore();
    //     DI.register<AppStore>(app);
    //
    //     final lease = MockPlusLeaseStore();
    //     DI.register<PlusLeaseStore>(lease);
    //
    //     final vpn = MockPlusVpnStore();
    //     DI.register<PlusVpnStore>(vpn);
    //
    //     final persistence = MockPersistence();
    //     DI.register<Persistence>(persistence);
    //
    //     final subject = PlusStore();
    //
    //     // Plus should autostart after app started and VPN was active before
    //     subject.plusEnabled = true;
    //     when(vpn.getStatus()).thenReturn(VpnStatus.deactivated);
    //     await subject.reactToAppStatus(true);
    //     verify(app.reconfiguring(any)).called(1);
    //     verify(vpn.setVpnActive(any, true)).called(1);
    //     verify(app.plusActivated(any, true));
    //
    //     // Plus should pause when app got paused
    //     when(vpn.getStatus()).thenReturn(VpnStatus.activated);
    //     await subject.reactToAppStatus(false);
    //     verify(app.reconfiguring(any)).called(1);
    //     verify(vpn.setVpnActive(any, false)).called(1);
    //     verify(app.plusActivated(any, false));
    //   });
    // });
  });

  group("storeErrors", () {
    test("switchPlusFailing", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final ops = MockPlusOps();
        Core.register<PlusOps>(ops);

        Core.register<PlusKeypairStore>(MockPlusKeypairStore());
        Core.register<PlusGatewayStore>(MockPlusGatewayStore());

        final app = MockAppStore();
        Core.register<AppStore>(app);

        final lease = MockPlusLeaseStore();
        Core.register<PlusLeaseStore>(lease);

        final vpn = MockPlusVpnStore();
        Core.register<PlusVpnStore>(vpn);

        final persistence = MockPersistence();
        Core.register<Persistence>(persistence);

        final subject = PlusStore();

        // Flags reverted when wont turn on
        when(vpn.turnVpnOn(any)).thenThrow(Exception("some error"));
        await expectLater(subject.switchPlus(true, m), throwsException);
        verifyNever(lease.fetch(any));
        expect(subject.plusEnabled, false);

        // Flags reverted when is on, and wont turn off
        // subject.plusEnabled = true;
        // when(vpn.turnVpnOff(any)).thenThrow(Exception("some error"));
        // await expectLater(subject.switchPlus(false), throwsException);
        // expect(subject.plusEnabled, true);
      });
    });
  });
}
