import 'package:common/env/env.dart';
import 'package:common/plus/gateway/gateway.dart';
import 'package:common/plus/keypair/keypair.dart';
import 'package:common/plus/lease/channel.pg.dart';
import 'package:common/plus/lease/json.dart';
import 'package:common/plus/lease/lease.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
import 'fixtures.dart';
@GenerateNiceMocks([
  MockSpec<PlusLeaseStore>(),
  MockSpec<PlusLeaseOps>(),
  MockSpec<PlusLeaseJson>(),
  MockSpec<PlusGatewayStore>(),
  MockSpec<PlusKeypairStore>(),
  MockSpec<StageStore>(),
  MockSpec<EnvStore>(),
])
import 'lease_test.mocks.dart';

void main() {
  group("store", () {
    test("fetch", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockPlusLeaseOps();
        depend<PlusLeaseOps>(ops);

        final json = MockPlusLeaseJson();
        when(json.getLeases(any))
            .thenAnswer((_) => Future.value(fixtureLeaseEntries));
        depend<PlusLeaseJson>(json);

        final keypair = MockPlusKeypairStore();
        when(keypair.currentDevicePublicKey)
            .thenReturn("no lease for this key");
        depend<PlusKeypairStore>(keypair);

        final gateway = MockPlusGatewayStore();
        depend<PlusGatewayStore>(gateway);

        final subject = PlusLeaseStore();
        expect(subject.leases.isEmpty, true);
        expect(subject.leaseChanges, 0);
        verifyNever(gateway.selectGateway(any, any));

        await subject.fetch(trace);
        expect(subject.leases.length, 3);
        expect(subject.leases.first.alias, "Solar quokka");
        expect(subject.leaseChanges, 1);
        expect(subject.currentLease, null);
        verify(gateway.selectGateway(any, null)).called(1);
      });
    });

    test("fetchWithCurrentLease", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockPlusLeaseOps();
        depend<PlusLeaseOps>(ops);

        final json = MockPlusLeaseJson();
        when(json.getLeases(any))
            .thenAnswer((_) => Future.value(fixtureLeaseEntries));
        depend<PlusLeaseJson>(json);

        final keypair = MockPlusKeypairStore();
        when(keypair.currentDevicePublicKey)
            .thenReturn("6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=");
        depend<PlusKeypairStore>(keypair);

        final gateway = MockPlusGatewayStore();
        depend<PlusGatewayStore>(gateway);

        final subject = PlusLeaseStore();
        expect(subject.leases.isEmpty, true);
        expect(subject.leaseChanges, 0);
        verifyNever(gateway.selectGateway(any, any));

        await subject.fetch(trace);
        expect(subject.leaseChanges, 1);
        expect(subject.currentLease, isNotNull);
        expect(subject.currentLease!.alias, "Solar quokka");
        verify(gateway.selectGateway(
          any,
          "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=",
        )).called(1);
      });
    });

    test("newLease", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockPlusLeaseOps();
        depend<PlusLeaseOps>(ops);

        final json = MockPlusLeaseJson();
        when(json.getLeases(any))
            .thenAnswer((_) => Future.value(fixtureLeaseEntries));
        depend<PlusLeaseJson>(json);

        final keypair = MockPlusKeypairStore();
        when(keypair.currentDevicePublicKey)
            .thenReturn("6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=");
        depend<PlusKeypairStore>(keypair);

        final gateway = MockPlusGatewayStore();
        depend<PlusGatewayStore>(gateway);

        // No leases at first
        final subject = PlusLeaseStore();
        expect(subject.leases.isEmpty, true);

        // After posting, it should fetch leases (and we have a matching one in fixtures)
        await subject.newLease(
            trace, "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=");
        verify(json.postLease(any, any)).called(1);
        expect(subject.currentLease, isNotNull);
        expect(subject.currentLease!.alias, "Solar quokka");
      });
    });

    test("deleteLease", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockPlusLeaseOps();
        depend<PlusLeaseOps>(ops);

        final json = MockPlusLeaseJson();
        when(json.getLeases(any))
            .thenAnswer((_) => Future.value(fixtureLeaseEntries));
        depend<PlusLeaseJson>(json);

        final keypair = MockPlusKeypairStore();
        when(keypair.currentDevicePublicKey)
            .thenReturn("6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=");
        depend<PlusKeypairStore>(keypair);

        final gateway = MockPlusGatewayStore();
        depend<PlusGatewayStore>(gateway);

        final subject = PlusLeaseStore();
        await subject.deleteLease(trace, fixtureLeaseEntries.first.toLease);
        verify(json.deleteLease(any, any)).called(1);
      });
    });
  });

  group("storeErrors", () {
    test("newLeasePostFailing", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockPlusLeaseOps();
        depend<PlusLeaseOps>(ops);

        final json = MockPlusLeaseJson();
        when(json.postLease(any, any)).thenThrow(Exception("post failing"));
        depend<PlusLeaseJson>(json);

        final keypair = MockPlusKeypairStore();
        when(keypair.currentDevicePublicKey)
            .thenReturn("6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=");
        depend<PlusKeypairStore>(keypair);

        final gateway = MockPlusGatewayStore();
        depend<PlusGatewayStore>(gateway);

        final subject = PlusLeaseStore();

        await expectLater(
          subject.newLease(
              trace, "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4="),
          throwsException,
        );
      });
    });

    test("newLeaseButNoMatchingLeaseReturned", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockPlusLeaseOps();
        depend<PlusLeaseOps>(ops);

        final json = MockPlusLeaseJson();
        when(json.getLeases(any))
            .thenAnswer((_) => Future.value(fixtureLeaseEntries));
        depend<PlusLeaseJson>(json);

        final keypair = MockPlusKeypairStore();
        when(keypair.currentDevicePublicKey)
            .thenReturn("no lease for this key");
        depend<PlusKeypairStore>(keypair);

        final gateway = MockPlusGatewayStore();
        depend<PlusGatewayStore>(gateway);

        final subject = PlusLeaseStore();

        await expectLater(
          subject.newLease(
              trace, "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4="),
          throwsA(isA<NoCurrentLeaseException>()),
        );
      });
    });

    test("newLeaseButTooManyLeases", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockPlusLeaseOps();
        depend<PlusLeaseOps>(ops);

        final json = MockPlusLeaseJson();
        when(json.postLease(any, any)).thenThrow(TooManyLeasesException());
        when(json.getLeases(any))
            .thenAnswer((_) => Future.value(fixtureLeaseEntries));
        depend<PlusLeaseJson>(json);

        final env = MockEnvStore();
        when(env.deviceName).thenReturn("Solar quokka");
        depend<EnvStore>(env);

        final keypair = MockPlusKeypairStore();
        when(keypair.currentDevicePublicKey)
            .thenReturn("6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=");
        depend<PlusKeypairStore>(keypair);

        final gateway = MockPlusGatewayStore();
        depend<PlusGatewayStore>(gateway);

        final subject = PlusLeaseStore();
        await subject.fetch(trace);

        await expectLater(
          subject.newLease(
              trace, "hO25cJ88KQ8uQZ0Tn71ibz7wUbnvFecmHWgqXzr7IAc="),
          throwsA(isA<TooManyLeasesException>()),
        );

        // It tried to delete the old lease for this device and get a new one
        verify(json.deleteLease(any, any)).called(1);
        verify(json.postLease(any, any)).called(2);
      });
    });

    test("deleteLeasePostFailing", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());

        final ops = MockPlusLeaseOps();
        depend<PlusLeaseOps>(ops);

        final json = MockPlusLeaseJson();
        when(json.deleteLease(any, any)).thenThrow(Exception("delete failing"));
        depend<PlusLeaseJson>(json);

        final env = MockEnvStore();
        depend<EnvStore>(env);

        final gateway = MockPlusGatewayStore();
        depend<PlusGatewayStore>(gateway);

        final subject = PlusLeaseStore();
        await subject.fetch(trace);

        await expectLater(
          subject.deleteLease(trace, fixtureLeaseEntries.first.toLease),
          throwsException,
        );

        verify(json.deleteLease(any, any)).called(1);
      });
    });

    test("willRefreshWhenNeeded", () async {
      await withTrace((trace) async {
        final ops = MockPlusLeaseOps();
        depend<PlusLeaseOps>(ops);

        final json = MockPlusLeaseJson();
        depend<PlusLeaseJson>(json);

        final gateway = MockPlusGatewayStore();
        depend<PlusGatewayStore>(gateway);

        final route = StageRouteState.init().newTab(StageTab.home);
        final stage = MockStageStore();
        when(stage.route).thenReturn(route);
        depend<StageStore>(stage);

        final subject = PlusLeaseStore();
        verifyNever(json.getLeases(any));

        await subject.onRouteChanged(trace, route);
        verify(json.getLeases(any));
      });
    });
  });
}
