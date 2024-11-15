import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/env/env.dart';
import 'package:common/platform/plus/gateway/gateway.dart';
import 'package:common/platform/plus/keypair/keypair.dart';
import 'package:common/platform/plus/lease/json.dart';
import 'package:common/platform/plus/lease/lease.dart';
import 'package:common/platform/plus/plus.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/plus/lease/channel.pg.dart';
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
  MockSpec<PlusStore>(),
  MockSpec<StageStore>(),
  MockSpec<EnvStore>(),
  MockSpec<AccountStore>(),
])
import 'lease_test.mocks.dart';

void main() {
  group("store", () {
    test("fetch", () async {
      await withTrace((m) async {
        depend<StageStore>(MockStageStore());
        depend<PlusStore>(MockPlusStore());

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

        await subject.fetch(m);
        expect(subject.leases.length, 3);
        expect(subject.leases.first.alias, "Solar quokka");
        expect(subject.leaseChanges, 1);
        expect(subject.currentLease, null);
        verify(gateway.selectGateway(any, m)).called(1);
      });
    });

    test("fetchWithCurrentLease", () async {
      await withTrace((m) async {
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

        await subject.fetch(m);
        expect(subject.leaseChanges, 1);
        expect(subject.currentLease, isNotNull);
        expect(subject.currentLease!.alias, "Solar quokka");
        verify(gateway.selectGateway(
                "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=", m))
            .called(1);
      });
    });

    test("newLease", () async {
      await withTrace((m) async {
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
            "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=", m);
        verify(json.postLease(any, any)).called(1);
        expect(subject.currentLease, isNotNull);
        expect(subject.currentLease!.alias, "Solar quokka");
      });
    });

    test("deleteLease", () async {
      await withTrace((m) async {
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
        await subject.deleteLease(fixtureLeaseEntries.first.toLease, m);
        verify(json.deleteLease(any, any)).called(1);
      });
    });
  });

  group("storeErrors", () {
    test("newLeasePostFailing", () async {
      await withTrace((m) async {
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
          subject.newLease("sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=", m),
          throwsException,
        );
      });
    });

    test("newLeaseButNoMatchingLeaseReturned", () async {
      await withTrace((m) async {
        depend<StageStore>(MockStageStore());
        depend<PlusStore>(MockPlusStore());

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
          subject.newLease("sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=", m),
          throwsA(isA<NoCurrentLeaseException>()),
        );
      });
    });

    test("newLeaseButTooManyLeases", () async {
      await withTrace((m) async {
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
        await subject.fetch(m);

        await expectLater(
          subject.newLease("hO25cJ88KQ8uQZ0Tn71ibz7wUbnvFecmHWgqXzr7IAc=", m),
          throwsA(isA<TooManyLeasesException>()),
        );

        // No attempt to delete lease anymore
        verify(json.postLease(any, any)).called(1);
      });
    });

    test("deleteLeasePostFailing", () async {
      await withTrace((m) async {
        depend<StageStore>(MockStageStore());
        depend<PlusStore>(MockPlusStore());

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
        final ops = MockPlusLeaseOps();
        depend<PlusLeaseOps>(ops);
        depend<PlusStore>(MockPlusStore());

        final json = MockPlusLeaseJson();
        depend<PlusLeaseJson>(json);

        final gateway = MockPlusGatewayStore();
        depend<PlusGatewayStore>(gateway);

        final account = MockAccountStore();
        when(account.type).thenReturn(AccountType.plus);
        depend<AccountStore>(account);

        final route = StageRouteState.init().newTab(StageTab.home);
        final stage = MockStageStore();
        when(stage.route).thenReturn(route);
        depend<StageStore>(stage);

        final subject = PlusLeaseStore();
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
