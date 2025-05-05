import 'package:common/common/module/env/env.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/plus/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/plus/module/gateway/gateway.dart';
import 'package:common/plus/module/keypair/keypair.dart';
import 'package:common/plus/module/lease/lease.dart';
import 'package:common/plus/module/vpn/vpn.dart';
import 'package:common/plus/plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
import 'fixtures.dart';
import 'gateway/fixtures.dart';
import 'lease/fixtures.dart';
@GenerateNiceMocks([
  MockSpec<LeaseActor>(),
  MockSpec<VpnActor>(),
  MockSpec<KeypairActor>(),
  MockSpec<GatewayActor>(),
  MockSpec<PlusActor>(),
  MockSpec<Persistence>(),
  MockSpec<PlusOps>(),
  MockSpec<AppStore>(),
  MockSpec<EnvActor>(),
  MockSpec<DeviceStore>(),
  MockSpec<StageStore>(),
  MockSpec<PlusChannel>(),
  MockSpec<AccountStore>(),
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

        Core.register<GatewayActor>(MockGatewayActor());
        Core.register<PlusChannel>(MockPlusChannel());
        Core.register<AccountStore>(MockAccountStore());

        Core.register(CurrentKeypairValue());
        Core.register(CurrentLeaseValue());
        Core.register(CurrentGatewayValue());

        final plusEnabled = PlusEnabledValue();
        Core.register(plusEnabled);

        final subject = PlusActor();
        expect(plusEnabled.present, null);

        await subject.onCreate(m);
        expect(plusEnabled.present, true);
      });
    });

    test("newPlus", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final persistence = MockPersistence();
        Core.register<Persistence>(persistence, tag: Persistence.secure);
        Core.register<Persistence>(persistence);

        final device = MockDeviceStore();
        when(device.currentDeviceTag).thenReturn("some device tag");
        Core.register<DeviceStore>(device);

        final ops = MockPlusOps();
        Core.register<PlusOps>(ops);

        final currentGateway = CurrentGatewayValue();
        await currentGateway.change(m, fixtureGatewayEntries.first.toGateway);
        Core.register(currentGateway);

        final gateway = MockGatewayActor();
        Core.register<GatewayActor>(gateway);

        final currentKeypair = CurrentKeypairValue();
        await currentKeypair.change(m, Fixtures.keypair);
        Core.register(currentKeypair);

        final keypair = MockKeypairActor();
        Core.register<KeypairActor>(keypair);

        final app = MockAppStore();
        Core.register<AppStore>(app);

        final currentLease = CurrentLeaseValue();
        await currentLease.change(m, fixtureLeaseEntries.first.toLease);
        Core.register(currentLease);

        final lease = MockLeaseActor();
        Core.register<LeaseActor>(lease);

        final vpn = MockVpnActor();
        Core.register<VpnActor>(vpn);

        final plusEnabled = PlusEnabledValue();
        Core.register(plusEnabled);

        final subject = PlusActor();

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

        final currentLease = CurrentLeaseValue();
        await currentLease.change(m, fixtureLeaseEntries.first.toLease);
        Core.register(currentLease);

        final lease = MockLeaseActor();
        Core.register<LeaseActor>(lease);

        final vpn = MockVpnActor();
        Core.register<VpnActor>(vpn);

        final persistence = MockPersistence();
        Core.register<Persistence>(persistence);

        final plusEnabled = PlusEnabledValue();
        Core.register(plusEnabled);

        final subject = PlusActor();

        await subject.clearPlus(m);
        verify(lease.deleteLease(any, any)).called(1);
        verify(vpn.turnVpnOff(any)).called(1);
        verify(persistence.save(any, any, any));
      });
    });

    test("switchPlus", () async {
      await withTrace((m) async {
        final persistence = MockPersistence();
        Core.register<Persistence>(persistence, tag: Persistence.secure);
        Core.register<Persistence>(persistence);

        final device = MockDeviceStore();
        when(device.currentDeviceTag).thenReturn("some device tag");
        Core.register<DeviceStore>(device);

        final currentGateway = CurrentGatewayValue();
        await currentGateway.change(m, fixtureGatewayEntries.first.toGateway);
        Core.register(currentGateway);

        final gateway = MockGatewayActor();
        Core.register<GatewayActor>(gateway);

        final currentKeypair = CurrentKeypairValue();
        await currentKeypair.change(m, Fixtures.keypair);
        Core.register(currentKeypair);

        final keypair = MockKeypairActor();
        Core.register<KeypairActor>(keypair);

        final ops = MockPlusOps();
        Core.register<PlusOps>(ops);

        final app = MockAppStore();
        Core.register<AppStore>(app);

        final currentLease = CurrentLeaseValue();
        await currentLease.change(m, fixtureLeaseEntries.first.toLease);
        Core.register(currentLease);

        final lease = MockLeaseActor();
        Core.register<LeaseActor>(lease);

        final vpn = MockVpnActor();
        Core.register<VpnActor>(vpn);

        final plusEnabled = PlusEnabledValue();
        Core.register(plusEnabled);

        final subject = PlusActor();

        await subject.switchPlus(true, m);
        verify(vpn.turnVpnOn(any)).called(1);
        verify(lease.fetch(any, noRetry: true));
      });
    });
  });

  group("storeErrors", () {
    test("switchPlusFailing", () async {
      await withTrace((m) async {
        final persistence = MockPersistence();
        Core.register<Persistence>(persistence);
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        Core.register<StageStore>(MockStageStore());

        final ops = MockPlusOps();
        Core.register<PlusOps>(ops);

        Core.register<KeypairActor>(MockKeypairActor());
        Core.register<GatewayActor>(MockGatewayActor());

        final currentLease = CurrentLeaseValue();
        await currentLease.change(m, null);
        Core.register(currentLease);

        final currentKeypair = CurrentKeypairValue();
        await currentKeypair.change(m, Fixtures.keypair);
        Core.register(currentKeypair);

        final currentGateway = CurrentGatewayValue();
        await currentGateway.change(m, null);
        Core.register(currentGateway);

        final app = MockAppStore();
        Core.register<AppStore>(app);

        final lease = MockLeaseActor();
        Core.register<LeaseActor>(lease);

        final vpn = MockVpnActor();
        Core.register<VpnActor>(vpn);

        final plusEnabled = PlusEnabledValue();
        Core.register(plusEnabled);

        final subject = PlusActor();

        // Flags reverted when wont turn on
        when(vpn.turnVpnOn(any)).thenThrow(Exception("some error"));
        await expectLater(subject.switchPlus(true, m), throwsException);
        verifyNever(lease.fetch(any));
        expect(plusEnabled.present, false);
      });
    });
  });
}
