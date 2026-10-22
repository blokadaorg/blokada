import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/plus/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/features/plus/domain/bypass/bypass.dart';
import 'package:common/src/features/plus/domain/gateway/gateway.dart';
import 'package:common/src/features/plus/domain/keypair/keypair.dart';
import 'package:common/src/features/plus/domain/lease/lease.dart';
import 'package:common/src/features/plus/domain/vpn/vpn.dart';
import 'package:common/src/features/plus/domain/plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';
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
  // newPlus confirms a new location with a haptic, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

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

        final bypassed = BypassedPackagesValue();
        await bypassed.change(m, <String>{});
        Core.register(bypassed);

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

        final bypassed = BypassedPackagesValue();
        await bypassed.change(m, <String>{});
        Core.register(bypassed);

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

    test("switchPlusKeepsPlusOnWhileStartIsPending", () async {
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

        final bypassed = BypassedPackagesValue();
        await bypassed.change(m, <String>{});
        Core.register(bypassed);

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

        // iOS holds the start during an extension update: no error sheet
        // (StageStore is not registered), Plus and the lease stay.
        when(vpn.turnVpnOn(any)).thenThrow(VpnStartPendingException());
        await subject.switchPlus(true, m);
        expect(plusEnabled.present, true);
        verify(app.plusActivated(false, any)).called(1);
        verifyNever(lease.deleteLease(any, any));
        verifyNever(lease.fetch(any, noRetry: true));
        verify(vpn.turnVpnOff(any)).called(1); // only the stop that always comes first
      });
    });

    test("switchPlusKeepsPlusOnWhenARetryStartIsPending", () async {
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

        final bypassed = BypassedPackagesValue();
        await bypassed.change(m, <String>{});
        Core.register(bypassed);

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

        // iOS holds the start during an extension update: no error sheet
        // (StageStore is not registered), Plus and the lease stay.
        // The first start works but the connectivity check fails, and the
        // retry's start is the one iOS holds.
        var starts = 0;
        when(vpn.turnVpnOn(any)).thenAnswer((_) async {
          if (starts++ > 0) throw VpnStartPendingException();
        });
        when(lease.fetch(any, noRetry: true)).thenThrow(Exception("no connectivity"));
        await subject.switchPlus(true, m);
        expect(plusEnabled.present, true);
        verify(app.plusActivated(false, any)).called(1);
        verifyNever(lease.deleteLease(any, any));
      });
    });

    test("reactToAppStatusLeavesAPendingStartToTheOs", () async {
      await withTrace((m) async {
        final persistence = MockPersistence();
        Core.register<Persistence>(persistence);

        final app = MockAppStore();
        when(app.conditions).thenReturn(AppStatusStrategy(accountIsPlus: true));
        when(app.status).thenReturn(AppStatus.activatedCloud);
        Core.register<AppStore>(app);

        final vpnStatus = CurrentVpnStatusValue();
        vpnStatus.now = VpnStatus.deactivated;
        Core.register(vpnStatus);

        final vpn = MockVpnActor();
        when(vpn.startPending).thenReturn(true);
        Core.register<VpnActor>(vpn);

        final plusEnabled = PlusEnabledValue();
        await plusEnabled.change(m, true);
        Core.register(plusEnabled);

        // Plus is on but the tunnel is down: normally a restart, but iOS
        // already holds a start and brings the tunnel up itself.
        final subject = PlusActor();
        await subject.reactToAppStatus(m);
        verifyNever(vpn.turnVpnOff(any));
        verifyNever(vpn.turnVpnOn(any));
      });
    });

    test("reactToAppPauseLeavesAPendingStartToTheOs", () async {
      await withTrace((m) async {
        final persistence = MockPersistence();
        Core.register<Persistence>(persistence);

        final app = MockAppStore();
        when(app.conditions).thenReturn(AppStatusStrategy(accountIsPlus: true));
        when(app.status).thenReturn(AppStatus.activatedCloud);
        Core.register<AppStore>(app);

        final vpnStatus = CurrentVpnStatusValue();
        vpnStatus.now = VpnStatus.deactivated;
        Core.register(vpnStatus);

        final vpn = MockVpnActor();
        when(vpn.startPending).thenReturn(true);
        Core.register<VpnActor>(vpn);

        final plusEnabled = PlusEnabledValue();
        await plusEnabled.change(m, true);
        Core.register(plusEnabled);

        // Back in the foreground with Plus on and the tunnel down: normally a
        // restart, but iOS already holds a start.
        final subject = PlusActor();
        await subject.reactToAppPause(true, m);
        verifyNever(vpn.turnVpnOff(any));
        verifyNever(vpn.turnVpnOn(any));
      });
    });

    test("reactToAppPauseIgnoresPlusWhenAccountIsNotPlus", () async {
      await withTrace((m) async {
        final persistence = MockPersistence();
        Core.register<Persistence>(persistence, tag: Persistence.secure);
        Core.register<Persistence>(persistence);

        final device = MockDeviceStore();
        when(device.currentDeviceTag).thenReturn("some device tag");
        Core.register<DeviceStore>(device);

        final app = MockAppStore();
        when(app.conditions).thenReturn(AppStatusStrategy(accountIsPlus: false));
        Core.register<AppStore>(app);

        Core.register<StageStore>(MockStageStore());
        Core.register<GatewayActor>(MockGatewayActor());
        Core.register<KeypairActor>(MockKeypairActor());
        Core.register<LeaseActor>(MockLeaseActor());
        Core.register<AccountStore>(MockAccountStore());
        Core.register(BypassedPackagesValue());

        final currentGateway = CurrentGatewayValue();
        await currentGateway.change(m, fixtureGatewayEntries.first.toGateway);
        Core.register(currentGateway);

        final currentKeypair = CurrentKeypairValue();
        await currentKeypair.change(m, Fixtures.keypair);
        Core.register(currentKeypair);

        final currentLease = CurrentLeaseValue();
        await currentLease.change(m, fixtureLeaseEntries.first.toLease);
        Core.register(currentLease);

        final vpnStatus = CurrentVpnStatusValue();
        vpnStatus.now = VpnStatus.deactivated;
        Core.register(vpnStatus);

        final vpn = MockVpnActor();
        Core.register<VpnActor>(vpn);

        final plusEnabled = PlusEnabledValue();
        Core.register(plusEnabled);
        await plusEnabled.change(m, true);

        final subject = PlusActor();
        await subject.reactToAppPause(true, m);

        verifyNever(vpn.turnVpnOn(any));
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
        // Leases are refreshed first; the connectivity check never runs.
        verify(lease.fetch(any)).called(1);
        verifyNever(lease.fetch(any, noRetry: true));
        expect(plusEnabled.present, false);
      });
    });
  });
}
