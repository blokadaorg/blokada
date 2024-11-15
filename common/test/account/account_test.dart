import 'dart:convert';

import 'package:common/core/core.dart';
import 'package:common/persistence/persistence.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/account/channel.pg.dart';
import 'package:common/platform/account/json.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<AccountJson>(),
  MockSpec<StageStore>(),
  MockSpec<SecurePersistenceService>(),
  MockSpec<AccountOps>(),
  MockSpec<AccountStore>(),
])
import 'account_test.mocks.dart';
import 'fixtures.dart';

void main() {
  group("store", () {
    test("loadWillReadFromPersistence", () async {
      await withTrace((m) async {
        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any, isBackup: true))
            .thenAnswer((_) => Future.value(jsonDecode(fixtureJsonAccount)));
        depend<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        depend<AccountOps>(ops);

        final subject = AccountStore();
        mockAct(subject);

        await subject.load(m);

        verify(persistence.loadOrThrow(any, any, isBackup: true)).called(1);
        expect(subject.account!.id, "mockedmocked");
        expect(subject.account!.type, AccountType.cloud);
        expect(subject.account!.jsonAccount.active, true);
      });
    });

    test("createWillPostAccountAndWriteToPersistence", () async {
      await withTrace((m) async {
        final persistence = MockSecurePersistenceService();
        depend<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        depend<AccountOps>(ops);

        final json = MockAccountJson();
        when(json.postAccount(m)).thenAnswer((_) =>
            Future.value(JsonAccount.fromJson(jsonDecode(fixtureJsonAccount))));
        depend<AccountJson>(json);

        final subject = AccountStore();
        mockAct(subject);

        await subject.create(m);

        verify(persistence.save(any, any, any, isBackup: true)).called(1);
        expect(subject.account!.id, "mockedmocked");
        expect(subject.account!.type, AccountType.cloud);
        expect(subject.account!.jsonAccount.active, true);
      });
    });

    test("fetchWillFetchFromApiAndWriteToPersistence", () async {
      await withTrace((m) async {
        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any, isBackup: true))
            .thenAnswer((_) => Future.value(jsonDecode(fixtureJsonAccount)));
        depend<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        depend<AccountOps>(ops);

        final json = MockAccountJson();
        when(json.getAccount(any, any)).thenAnswer((_) =>
            Future.value(JsonAccount.fromJson(jsonDecode(fixtureJsonAccount))));
        depend<AccountJson>(json);

        final subject = AccountStore();
        mockAct(subject);

        await subject.load(m);
        await subject.fetch(m);

        verify(persistence.save(any, any, any, isBackup: true)).called(1);
      });
    });

    test("restoreWillGetAccountWithProvidedId", () async {
      await withTrace((m) async {
        depend<StageStore>(MockStageStore());

        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any, isBackup: true))
            .thenAnswer((_) => Future.value(jsonDecode(fixtureJsonAccount)));
        depend<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        depend<AccountOps>(ops);

        final json = MockAccountJson();
        when(json.getAccount(any, any)).thenAnswer((_) => Future.value(
            JsonAccount.fromJson(jsonDecode(fixtureJsonAccount2))));
        depend<AccountJson>(json);

        final subject = AccountStore();
        mockAct(subject);

        // First load as normal
        await subject.load(m);

        expect(subject.account!.id, "mockedmocked");

        // Then try restoring another account
        await subject.restore("mocked2", m);

        verify(json.getAccount("mocked2", m)).called(1);
        verify(persistence.save(any, any, any, isBackup: true)).called(1);
        expect(subject.account!.id, "mocked2");
        expect(subject.account!.type, AccountType.libre);
        expect(subject.account!.jsonAccount.active, false);
      });
    });

    test("expireOfflineWillExpireAccountAndWriteToPersistence", () async {
      await withTrace((m) async {
        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any, isBackup: true))
            .thenAnswer((_) => Future.value(jsonDecode(fixtureJsonAccount)));
        depend<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        depend<AccountOps>(ops);

        final json = MockAccountJson();
        depend<AccountJson>(json);

        final subject = AccountStore();
        mockAct(subject);

        await subject.load(m);

        expect(subject.account!.id, "mockedmocked");
        expect(subject.account!.type, AccountType.cloud);
        expect(subject.account!.jsonAccount.active, true);

        await subject.expireOffline(m);

        verify(persistence.save(any, any, any, isBackup: true)).called(1);
        expect(subject.account!.id, "mockedmocked");
        expect(subject.account!.type, AccountType.libre);
        expect(subject.account!.jsonAccount.active, false);
      });
    });

    test("proposeWillUpdateAccountAndWriteToPersistence", () async {
      await withTrace((m) async {
        final persistence = MockSecurePersistenceService();
        depend<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        depend<AccountOps>(ops);

        final subject = AccountStore();

        await subject.propose(
            JsonAccount.fromJson(jsonDecode(fixtureJsonAccount2)), m);

        verify(persistence.save(any, any, any, isBackup: true)).called(1);
        expect(subject.account!.id, "mocked2");
      });
    });
  });

  group("storeErrors", () {
    test("willReturnErrorOnEmptyCache", () async {
      await withTrace((m) async {
        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any, isBackup: true))
            .thenThrow(Exception("no account in cache"));
        depend<SecurePersistenceService>(persistence);

        depend<AccountJson>(MockAccountJson());

        final ops = MockAccountOps();
        depend<AccountOps>(ops);

        final subject = AccountStore();

        await expectLater(subject.load(m), throwsException);
      });
    });

    test("fetchWillReturnErrorWhenNoLoadCalledBefore", () async {
      await withTrace((m) async {
        final subject = AccountStore();

        await expectLater(
            subject.fetch(m), throwsA(isA<AccountNotInitialized>()));
      });
    });

    // test("restoreWillThrowOnInvalidAccountId", () async {
    //   await withTrace((m) async {
    //     depend<StageStore>(MockStageStore());
    //     final subject = AccountStore();
    //
    //     // Empty account ID
    //     await expectLater(
    //         subject.restore(""), throwsA(isA<InvalidAccountId>()));
    //   });
    // });

    // test("will generate new keypair on empty cache", () async {
    //   final mCache = MockSecurePersistenceSpec();
    //   when(mCache.loadOrThrow(any)).thenAnswer((_) =>
    //       Future.value(jsonDecode(Fixtures.cacheAccount))
    //   );
    //   depend<SecurePersistenceSpec>(mCache);
    //
    //   final mKeypair = MockKeypairService();
    //   when(mKeypair.generate()).thenAnswer((_) =>
    //       Future.value(AccountKeypair("pub", "priv"))
    //   );
    //   depend<KeypairService>(mKeypair);
    //
    //   depend<ApiSpec>(MockApiSpec());
    //
    //   final store = AccountStore();
    //
    //   try {
    //     await store.load(DebugTrace.as("account"));
    //     verify(mKeypair.generate()).called(1);
    //     verify(mCache.save(any, any, any));
    //   } catch (e, s) {
    //     fail("exception thrown: $e\n$s");
    //   }
    // });
  });

  group("binder", () {
    test("onAccount", () async {
      await withTrace((m) async {
        final ops = MockAccountOps();
        depend<AccountOps>(ops);

        final persistence = MockSecurePersistenceService();
        depend<SecurePersistenceService>(persistence);

        final store = AccountStore();
        depend<AccountStore>(store);

        await store.propose(
            JsonAccount.fromJson(jsonDecode(fixtureJsonAccount2)), m);

        verify(ops.doAccountChanged(any)).called(1);
      });
    });
  });
}
