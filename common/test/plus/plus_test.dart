import 'package:common/app/app.dart';
import 'package:common/device/device.dart';
import 'package:common/env/env.dart';
import 'package:common/persistence/persistence.dart';
import 'package:common/plus/channel.pg.dart';
import 'package:common/plus/gateway/gateway.dart';
import 'package:common/plus/keypair/keypair.dart';
import 'package:common/plus/lease/lease.dart';
import 'package:common/plus/plus.dart';
import 'package:common/plus/vpn/vpn.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
import 'fixtures.dart';
import 'gateway/fixtures.dart';
import 'lease/fixtures.dart';
@GenerateNiceMocks([
  MockSpec<PlusLeaseStore>(),
  MockSpec<PlusVpnStore>(),
  MockSpec<PlusKeypairStore>(),
  MockSpec<PlusGatewayStore>(),
  MockSpec<PlusStore>(),
  MockSpec<PersistenceService>(),
  MockSpec<PlusOps>(),
  MockSpec<AppStore>(),
  MockSpec<EnvStore>(),
  MockSpec<DeviceStore>(),
  MockSpec<StageStore>(),
])
import 'plus_test.mocks.dart';

void main() {
  group("store", () {
    test("load", () async {
      await withTrace((trace) async {
        final ops = MockPlusOps();
        depend<PlusOps>(ops);

        final persistence = MockPersistenceService();
        when(persistence.load(any, any)).thenAnswer((_) => Future.value("1"));
        depend<PersistenceService>(persistence);

        final subject = PlusStore();
        expect(subject.plusEnabled, false);

        await subject.load(trace);
        expect(subject.plusEnabled, true);
      });
    });

    test("newPlus", () async {
      await withTrace((trace) async {
        final device = MockDeviceStore();
        when(device.currentDeviceTag).thenReturn("some device tag");
        depend<DeviceStore>(device);

        final ops = MockPlusOps();
        depend<PlusOps>(ops);

        final gateway = MockPlusGatewayStore();
        when(gateway.currentGateway)
            .thenReturn(fixtureGatewayEntries.first.toGateway);
        depend<PlusGatewayStore>(gateway);

        final keypair = MockPlusKeypairStore();
        when(keypair.currentKeypair).thenReturn(Fixtures.keypair);
        depend<PlusKeypairStore>(keypair);

        final app = MockAppStore();
        depend<AppStore>(app);

        final lease = MockPlusLeaseStore();
        when(lease.currentLease).thenReturn(fixtureLeaseEntries.first.toLease);
        depend<PlusLeaseStore>(lease);

        final vpn = MockPlusVpnStore();
        depend<PlusVpnStore>(vpn);

        final persistence = MockPersistenceService();
        depend<PersistenceService>(persistence);

        final subject = PlusStore();

        await subject.newPlus(trace, "some gateway id");
        verify(app.reconfiguring(any)).called(1);
        verify(lease.newLease(any, "some gateway id")).called(1);
        verify(vpn.turnVpnOn(any)).called(1);
        verify(lease.fetch(any));
        verify(persistence.saveString(any, any, any));
      });
    });

    test('clearPlus', () async {
      await withTrace((trace) async {
        final ops = MockPlusOps();
        depend<PlusOps>(ops);

        final app = MockAppStore();
        depend<AppStore>(app);

        final lease = MockPlusLeaseStore();
        when(lease.currentLease).thenReturn(fixtureLeaseEntries.first.toLease);
        depend<PlusLeaseStore>(lease);

        final vpn = MockPlusVpnStore();
        depend<PlusVpnStore>(vpn);

        final persistence = MockPersistenceService();
        depend<PersistenceService>(persistence);

        final subject = PlusStore();

        await subject.clearPlus(trace);
        verify(lease.deleteLease(any, any)).called(1);
        verify(vpn.turnVpnOff(any)).called(1);
        verify(persistence.saveString(any, any, any));
      });
    });

    test("switchPlus", () async {
      await withTrace((trace) async {
        final device = MockDeviceStore();
        when(device.currentDeviceTag).thenReturn("some device tag");
        depend<DeviceStore>(device);

        final gateway = MockPlusGatewayStore();
        when(gateway.currentGateway)
            .thenReturn(fixtureGatewayEntries.first.toGateway);
        depend<PlusGatewayStore>(gateway);

        final keypair = MockPlusKeypairStore();
        when(keypair.currentKeypair).thenReturn(Fixtures.keypair);
        depend<PlusKeypairStore>(keypair);

        final ops = MockPlusOps();
        depend<PlusOps>(ops);

        final app = MockAppStore();
        depend<AppStore>(app);

        final lease = MockPlusLeaseStore();
        when(lease.currentLease).thenReturn(fixtureLeaseEntries.first.toLease);
        depend<PlusLeaseStore>(lease);

        final vpn = MockPlusVpnStore();
        depend<PlusVpnStore>(vpn);

        final persistence = MockPersistenceService();
        depend<PersistenceService>(persistence);

        final subject = PlusStore();

        await subject.switchPlus(trace, true);
        verify(vpn.turnVpnOn(any)).called(1);
        verify(lease.fetch(any));
      });
    });

    // test("reactToAppStatus", () async {
    //   await withTrace((trace) async {
    //     final ops = MockPlusOps();
    //     depend<PlusOps>(ops);
    //
    //     final app = MockAppStore();
    //     depend<AppStore>(app);
    //
    //     final lease = MockPlusLeaseStore();
    //     depend<PlusLeaseStore>(lease);
    //
    //     final vpn = MockPlusVpnStore();
    //     depend<PlusVpnStore>(vpn);
    //
    //     final persistence = MockPersistenceService();
    //     depend<PersistenceService>(persistence);
    //
    //     final subject = PlusStore();
    //
    //     // Plus should autostart after app started and VPN was active before
    //     subject.plusEnabled = true;
    //     when(vpn.getStatus()).thenReturn(VpnStatus.deactivated);
    //     await subject.reactToAppStatus(trace, true);
    //     verify(app.reconfiguring(any)).called(1);
    //     verify(vpn.setVpnActive(any, true)).called(1);
    //     verify(app.plusActivated(any, true));
    //
    //     // Plus should pause when app got paused
    //     when(vpn.getStatus()).thenReturn(VpnStatus.activated);
    //     await subject.reactToAppStatus(trace, false);
    //     verify(app.reconfiguring(any)).called(1);
    //     verify(vpn.setVpnActive(any, false)).called(1);
    //     verify(app.plusActivated(any, false));
    //   });
    // });
  });

  group("storeErrors", () {
    test("switchPlusFailing", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockPlusOps();
        depend<PlusOps>(ops);

        depend<PlusKeypairStore>(MockPlusKeypairStore());
        depend<PlusGatewayStore>(MockPlusGatewayStore());

        final app = MockAppStore();
        depend<AppStore>(app);

        final lease = MockPlusLeaseStore();
        depend<PlusLeaseStore>(lease);

        final vpn = MockPlusVpnStore();
        depend<PlusVpnStore>(vpn);

        final persistence = MockPersistenceService();
        depend<PersistenceService>(persistence);

        final subject = PlusStore();

        // Flags reverted when wont turn on
        when(vpn.turnVpnOn(any)).thenThrow(Exception("some error"));
        await expectLater(subject.switchPlus(trace, true), throwsException);
        verifyNever(lease.fetch(any));
        expect(subject.plusEnabled, false);

        // Flags reverted when is on, and wont turn off
        // subject.plusEnabled = true;
        // when(vpn.turnVpnOff(any)).thenThrow(Exception("some error"));
        // await expectLater(subject.switchPlus(trace, false), throwsException);
        // expect(subject.plusEnabled, true);
      });
    });
  });
}
