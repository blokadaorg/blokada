import 'package:common/common/module/env/env.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/plus/module/gateway/gateway.dart';
import 'package:common/plus/module/keypair/keypair.dart';
import 'package:common/plus/module/lease/lease.dart';
import 'package:common/plus/plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';
import '../fixtures.dart';
import 'fixtures.dart';
@GenerateNiceMocks([
  MockSpec<LeaseActor>(),
  MockSpec<LeaseChannel>(),
  MockSpec<LeaseApi>(),
  MockSpec<GatewayActor>(),
  MockSpec<KeypairActor>(),
  MockSpec<PlusActor>(),
  MockSpec<StageStore>(),
  MockSpec<EnvActor>(),
  MockSpec<AccountStore>(),
  MockSpec<CurrentKeypairValue>(),
  MockSpec<Persistence>(),
  MockSpec<DeviceStore>(),
])
import 'lease_test.mocks.dart';

void main() {
  group("store", () {
    test("fetch", () async {
      await withTrace((m) async {
        Core.register<Persistence>(MockPersistence(), tag: Persistence.secure);

        Core.register<StageStore>(MockStageStore());
        Core.register<PlusActor>(MockPlusActor());

        final ops = MockLeaseChannel();
        Core.register<LeaseChannel>(ops);

        final json = MockLeaseApi();
        when(json.getLeases(any))
            .thenAnswer((_) => Future.value(fixtureLeaseEntries));
        Core.register<LeaseApi>(json);

        final keypair = CurrentKeypairValue();
        keypair.change(m, Fixtures.keypair);
        Core.register<CurrentKeypairValue>(keypair);

        final gateway = MockGatewayActor();
        Core.register<GatewayActor>(gateway);

        final currentLease = CurrentLeaseValue();
        Core.register(currentLease);

        final leases = LeasesValue();
        Core.register(leases);

        final subject = LeaseActor();
        expect(leases.present, null);
        verifyNever(gateway.selectGateway(any, any));

        await subject.fetch(m);
        expect(leases.present!.length, 3);
        expect(leases.present!.first.alias, "Solar quokka");
        expect(currentLease.present, null);
        verify(gateway.selectGateway(any, m)).called(1);
      });
    });

    test("fetchWithCurrentLease", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final ops = MockLeaseChannel();
        Core.register<LeaseChannel>(ops);

        final json = MockLeaseApi();
        when(json.getLeases(any))
            .thenAnswer((_) => Future.value(fixtureLeaseEntries));
        Core.register<LeaseApi>(json);

        Core.register<Persistence>(MockPersistence(), tag: Persistence.secure);
        final keypair = CurrentKeypairValue();
        await keypair.change(
            m,
            Keypair(
                publicKey: "6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=",
                privateKey: "sk"));
        Core.register<CurrentKeypairValue>(keypair);

        final gateway = MockGatewayActor();
        Core.register<GatewayActor>(gateway);

        final currentLease = CurrentLeaseValue();
        Core.register(currentLease);

        final leases = LeasesValue();
        Core.register(leases);

        final subject = LeaseActor();
        expect(leases.present, null);
        verifyNever(gateway.selectGateway(any, any));

        await subject.fetch(m);
        expect(currentLease.present, isNotNull);
        expect(currentLease.present!.alias, "Solar quokka");
        verify(gateway.selectGateway(
                "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=", m))
            .called(1);
      });
    });

    test("newLease", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final device = MockDeviceStore();
        when(device.deviceAlias).thenReturn("Solar quokka");
        Core.register<DeviceStore>(device);

        final ops = MockLeaseChannel();
        Core.register<LeaseChannel>(ops);

        final json = MockLeaseApi();
        when(json.getLeases(any))
            .thenAnswer((_) => Future.value(fixtureLeaseEntries));
        Core.register<LeaseApi>(json);

        Core.register<Persistence>(MockPersistence(), tag: Persistence.secure);
        final keypair = CurrentKeypairValue();
        await keypair.change(
            m,
            Keypair(
                publicKey: "6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=",
                privateKey: "sk"));
        Core.register<CurrentKeypairValue>(keypair);

        final currentLease = CurrentLeaseValue();
        Core.register(currentLease);

        final leases = LeasesValue();
        Core.register(leases);

        final gateway = MockGatewayActor();
        Core.register<GatewayActor>(gateway);

        // No leases at first
        final subject = LeaseActor();
        expect(leases.present, null);

        // After posting, it should fetch leases (and we have a matching one in fixtures)
        await subject.newLease(
            "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=", m);
        verify(json.postLease(any, any, any, any)).called(1);
        expect(currentLease.present, isNotNull);
        expect(currentLease.present!.alias, "Solar quokka");
      });
    });

    test("deleteLease", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final ops = MockLeaseChannel();
        Core.register<LeaseChannel>(ops);

        final json = MockLeaseApi();
        when(json.getLeases(any))
            .thenAnswer((_) => Future.value(fixtureLeaseEntries));
        Core.register<LeaseApi>(json);

        Core.register<Persistence>(MockPersistence(), tag: Persistence.secure);
        final keypair = CurrentKeypairValue();
        await keypair.change(
            m,
            Keypair(
                publicKey: "6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=",
                privateKey: "sk"));
        Core.register<CurrentKeypairValue>(keypair);

        Core.register(CurrentLeaseValue());

        final leases = LeasesValue();
        Core.register(leases);

        final gateway = MockGatewayActor();
        Core.register<GatewayActor>(gateway);

        final subject = LeaseActor();
        await subject.deleteLease(fixtureLeaseEntries.first.toLease, m);
        verify(json.deleteLease(any, any)).called(1);
      });
    });
  });

  group("storeErrors", () {
    // test("newLeasePostFailing", () async {
    //   await withTrace((m) async {
    //     Core.register<StageStore>(MockStageStore());
    //
    //     final ops = MockLeaseChannel();
    //     Core.register<LeaseChannel>(ops);
    //
    //     final json = MockLeaseApi();
    //     when(json.postLease(any, any)).thenThrow(Exception("post failing"));
    //     Core.register<LeaseApi>(json);
    //
    //     final keypair = MockKeypairActor();
    //     when(keypair.currentDevicePublicKey)
    //         .thenReturn("6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=");
    //     Core.register<KeypairActor>(keypair);
    //
    //     final gateway = MockGatewayActor();
    //     Core.register<GatewayActor>(gateway);
    //
    //     final subject = LeaseActor();
    //
    //     await expectLater(
    //       subject.newLease("sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=", m),
    //       throwsException,
    //     );
    //   });
    // });
    //
    // test("newLeaseButNoMatchingLeaseReturned", () async {
    //   await withTrace((m) async {
    //     Core.register<StageStore>(MockStageStore());
    //     Core.register<PlusActor>(MockPlusActor());
    //
    //     final ops = MockLeaseChannel();
    //     Core.register<LeaseChannel>(ops);
    //
    //     final json = MockLeaseApi();
    //     when(json.getLeases(any))
    //         .thenAnswer((_) => Future.value(fixtureLeaseEntries));
    //     Core.register<LeaseApi>(json);
    //
    //     final keypair = MockKeypairActor();
    //     when(keypair.currentDevicePublicKey)
    //         .thenReturn("no lease for this key");
    //     Core.register<KeypairActor>(keypair);
    //
    //     final gateway = MockGatewayActor();
    //     Core.register<GatewayActor>(gateway);
    //
    //     final subject = LeaseActor();
    //
    //     await expectLater(
    //       subject.newLease("sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=", m),
    //       throwsA(isA<NoCurrentLeaseException>()),
    //     );
    //   });
    // });
    //
    // test("newLeaseButTooManyLeases", () async {
    //   await withTrace((m) async {
    //     Core.register<StageStore>(MockStageStore());
    //
    //     final ops = MockLeaseChannel();
    //     Core.register<LeaseChannel>(ops);
    //
    //     final json = MockLeaseApi();
    //     when(json.postLease(any, any)).thenThrow(TooManyLeasesException());
    //     when(json.getLeases(any))
    //         .thenAnswer((_) => Future.value(fixtureLeaseEntries));
    //     Core.register<LeaseApi>(json);
    //
    //     final env = MockEnvActor();
    //     when(env.deviceName).thenReturn("Solar quokka");
    //     Core.register<EnvActor>(env);
    //
    //     final keypair = MockKeypairActor();
    //     when(keypair.currentDevicePublicKey)
    //         .thenReturn("6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=");
    //     Core.register<KeypairActor>(keypair);
    //
    //     final gateway = MockGatewayActor();
    //     Core.register<GatewayActor>(gateway);
    //
    //     final subject = LeaseActor();
    //     await subject.fetch(m);
    //
    //     await expectLater(
    //       subject.newLease("hO25cJ88KQ8uQZ0Tn71ibz7wUbnvFecmHWgqXzr7IAc=", m),
    //       throwsA(isA<TooManyLeasesException>()),
    //     );
    //
    //     // No attempt to delete lease anymore
    //     verify(json.postLease(any, any, any, any)).called(1);
    //   });
    // });

    test("deleteLeasePostFailing", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());
        Core.register<PlusActor>(MockPlusActor());

        final ops = MockLeaseChannel();
        Core.register<LeaseChannel>(ops);

        final json = MockLeaseApi();
        when(json.deleteLease(any, any)).thenThrow(Exception("delete failing"));
        Core.register<LeaseApi>(json);

        final env = MockEnvActor();
        Core.register<EnvActor>(env);

        final gateway = MockGatewayActor();
        Core.register<GatewayActor>(gateway);

        Core.register(CurrentLeaseValue());

        final leases = LeasesValue();
        Core.register(leases);

        final subject = LeaseActor();
        await subject.fetch(m);

        await expectLater(
          subject.deleteLease(fixtureLeaseEntries.first.toLease, m),
          throwsException,
        );

        verify(json.deleteLease(any, any)).called(1);
      });
    });

    test("willRefreshWhenNeeded", () async {
      await withTrace((m) async {
        final ops = MockLeaseChannel();
        Core.register<LeaseChannel>(ops);
        Core.register<PlusActor>(MockPlusActor());

        final json = MockLeaseApi();
        Core.register<LeaseApi>(json);

        final gateway = MockGatewayActor();
        Core.register<GatewayActor>(gateway);

        final account = MockAccountStore();
        when(account.type).thenReturn(AccountType.plus);
        Core.register<AccountStore>(account);

        final route = StageRouteState.init().newTab(StageTab.home);
        final stage = MockStageStore();
        when(stage.route).thenReturn(route);
        Core.register<StageStore>(stage);

        Core.register(CurrentLeaseValue());

        final leases = LeasesValue();
        Core.register(leases);

        final subject = LeaseActor();
        verifyNever(json.getLeases(any));

        await subject.onRouteChanged(route, m);
        verify(json.getLeases(any));

        // Should not fetch lease if not Plus account
        when(account.type).thenReturn(AccountType.cloud);
        await subject.onRouteChanged(route, m);
        verifyNever(json.getLeases(any));
      });
    });
  });
}
