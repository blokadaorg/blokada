import 'package:common/app/app.dart';
import 'package:common/persistence/persistence.dart';
import 'package:common/plus/channel.pg.dart';
import 'package:common/plus/keypair/keypair.dart';
import 'package:common/plus/lease/lease.dart';
import 'package:common/plus/plus.dart';
import 'package:common/plus/vpn/vpn.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
import 'fixtures.dart';
import 'lease/fixtures.dart';
@GenerateNiceMocks([
  MockSpec<PlusLeaseStore>(),
  MockSpec<PlusVpnStore>(),
  MockSpec<PlusKeypairStore>(),
  MockSpec<PlusStore>(),
  MockSpec<PersistenceService>(),
  MockSpec<PlusOps>(),
  MockSpec<AppStore>(),
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
        final ops = MockPlusOps();
        depend<PlusOps>(ops);

        final app = MockAppStore();
        depend<AppStore>(app);

        final lease = MockPlusLeaseStore();
        depend<PlusLeaseStore>(lease);

        final vpn = MockPlusVpnStore();
        depend<PlusVpnStore>(vpn);

        final persistence = MockPersistenceService();
        depend<PersistenceService>(persistence);

        final subject = PlusStore();

        await subject.newPlus(trace, "some gateway id");
        verify(app.reconfiguring(any)).called(1);
        verify(lease.newLease(any, "some gateway id")).called(1);
        verify(vpn.setVpnActive(any, true)).called(1);
        verify(lease.fetch(any));
        verify(persistence.saveString(any, any, any));
        // todo: the vpn status feedback
        // verify(app.plusActivated(any, true));
      });
    });

    test('clearPlus', () async {
      await withTrace((trace) async {
        final ops = MockPlusOps();
        depend<PlusOps>(ops);

        final app = MockAppStore();
        depend<AppStore>(app);

        final lease = MockPlusLeaseStore();
        when(lease.getCurrentLease())
            .thenReturn(fixtureLeaseEntries.first.toLease);
        depend<PlusLeaseStore>(lease);

        final vpn = MockPlusVpnStore();
        depend<PlusVpnStore>(vpn);

        final persistence = MockPersistenceService();
        depend<PersistenceService>(persistence);

        final subject = PlusStore();

        await subject.clearPlus(trace);
        verify(app.reconfiguring(any)).called(1);
        verify(lease.deleteLease(any, any)).called(1);
        verify(vpn.setVpnActive(any, false)).called(1);
        verify(persistence.saveString(any, any, any));
        // todo: the vpn status feedback
        //verify(app.plusActivated(any, false));
      });
    });

    test("switchPlus", () async {
      await withTrace((trace) async {
        final ops = MockPlusOps();
        depend<PlusOps>(ops);

        final app = MockAppStore();
        depend<AppStore>(app);

        final lease = MockPlusLeaseStore();
        depend<PlusLeaseStore>(lease);

        final vpn = MockPlusVpnStore();
        depend<PlusVpnStore>(vpn);

        final persistence = MockPersistenceService();
        depend<PersistenceService>(persistence);

        final subject = PlusStore();

        await subject.switchPlus(trace, true);
        verify(app.reconfiguring(any)).called(1);
        verify(vpn.setVpnActive(any, true)).called(1);
        verify(lease.fetch(any));
        // todo: the vpn status feedback
        //verify(app.plusActivated(any, true));
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
        final ops = MockPlusOps();
        depend<PlusOps>(ops);

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
        when(vpn.setVpnActive(any, true)).thenThrow(Exception("some error"));
        await expectLater(subject.switchPlus(trace, true), throwsException);
        verify(app.reconfiguring(any)).called(1);
        verifyNever(lease.fetch(any));
        verify(app.plusActivated(any, false));
        expect(subject.plusEnabled, false);

        // Flags reverted when is on, and wont turn off
        subject.plusEnabled = true;
        when(vpn.setVpnActive(any, false)).thenThrow(Exception("some error"));
        await expectLater(subject.switchPlus(trace, false), throwsException);
        verify(app.reconfiguring(any)).called(1);
        verify(app.plusActivated(any, true));
        expect(subject.plusEnabled, true);
      });
    });
  });
}
