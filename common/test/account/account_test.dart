import 'dart:convert';

import 'package:common/account/account.dart';
import 'package:common/account/channel.pg.dart';
import 'package:common/account/json.dart';
import 'package:common/persistence/persistence.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
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
      await withTrace((trace) async {
        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any))
            .thenAnswer((_) => Future.value(jsonDecode(fixtureJsonAccount)));
        di.registerSingleton<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        di.registerSingleton<AccountOps>(ops);

        final subject = AccountStore();

        await subject.load(trace);

        verify(persistence.loadOrThrow(any, any)).called(1);
        expect(subject.account!.id, "mockedmocked");
        expect(subject.account!.type, AccountType.cloud);
        expect(subject.account!.jsonAccount.active, true);
      });
    });

    test("createWillPostAccountAndWriteToPersistence", () async {
      await withTrace((trace) async {
        final persistence = MockSecurePersistenceService();
        di.registerSingleton<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        di.registerSingleton<AccountOps>(ops);

        final json = MockAccountJson();
        when(json.postAccount(any)).thenAnswer((_) =>
            Future.value(JsonAccount.fromJson(jsonDecode(fixtureJsonAccount))));
        di.registerSingleton<AccountJson>(json);

        final subject = AccountStore();

        await subject.create(trace);

        verify(persistence.save(any, any, any)).called(1);
        expect(subject.account!.id, "mockedmocked");
        expect(subject.account!.type, AccountType.cloud);
        expect(subject.account!.jsonAccount.active, true);
      });
    });

    test("fetchWillFetchFromApiAndWriteToPersistence", () async {
      await withTrace((trace) async {
        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any))
            .thenAnswer((_) => Future.value(jsonDecode(fixtureJsonAccount)));
        di.registerSingleton<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        di.registerSingleton<AccountOps>(ops);

        final json = MockAccountJson();
        when(json.getAccount(any, any)).thenAnswer((_) =>
            Future.value(JsonAccount.fromJson(jsonDecode(fixtureJsonAccount))));
        di.registerSingleton<AccountJson>(json);

        final subject = AccountStore();

        await subject.load(trace);
        await subject.fetch(trace);

        verify(persistence.save(any, any, any)).called(1);
      });
    });

    test("restoreWillGetAccountWithProvidedId", () async {
      await withTrace((trace) async {
        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any))
            .thenAnswer((_) => Future.value(jsonDecode(fixtureJsonAccount)));
        di.registerSingleton<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        di.registerSingleton<AccountOps>(ops);

        final json = MockAccountJson();
        when(json.getAccount(any, any)).thenAnswer((_) => Future.value(
            JsonAccount.fromJson(jsonDecode(fixtureJsonAccount2))));
        di.registerSingleton<AccountJson>(json);

        final subject = AccountStore();

        // First load as normal
        await subject.load(trace);

        expect(subject.account!.id, "mockedmocked");

        // Then try restoring another account
        await subject.restore(trace, "mocked2");

        verify(json.getAccount(any, "mocked2")).called(1);
        verify(persistence.save(any, any, any)).called(1);
        expect(subject.account!.id, "mocked2");
        expect(subject.account!.type, AccountType.libre);
        expect(subject.account!.jsonAccount.active, false);
      });
    });

    test("expireOfflineWillExpireAccountAndWriteToPersistence", () async {
      await withTrace((trace) async {
        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any))
            .thenAnswer((_) => Future.value(jsonDecode(fixtureJsonAccount)));
        di.registerSingleton<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        di.registerSingleton<AccountOps>(ops);

        final json = MockAccountJson();
        di.registerSingleton<AccountJson>(json);

        final subject = AccountStore();

        await subject.load(trace);

        expect(subject.account!.id, "mockedmocked");
        expect(subject.account!.type, AccountType.cloud);
        expect(subject.account!.jsonAccount.active, true);

        await subject.expireOffline(trace);

        verify(persistence.save(any, any, any)).called(1);
        expect(subject.account!.id, "mockedmocked");
        expect(subject.account!.type, AccountType.libre);
        expect(subject.account!.jsonAccount.active, false);
      });
    });

    test("proposeWillUpdateAccountAndWriteToPersistence", () async {
      await withTrace((trace) async {
        final persistence = MockSecurePersistenceService();
        di.registerSingleton<SecurePersistenceService>(persistence);

        final ops = MockAccountOps();
        di.registerSingleton<AccountOps>(ops);

        final subject = AccountStore();

        await subject.propose(
            trace, JsonAccount.fromJson(jsonDecode(fixtureJsonAccount2)));

        verify(persistence.save(any, any, any)).called(1);
        expect(subject.account!.id, "mocked2");
      });
    });
  });

  group("storeErrors", () {
    test("willReturnErrorOnEmptyCache", () async {
      await withTrace((trace) async {
        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any))
            .thenThrow(Exception("no account in cache"));
        di.registerSingleton<SecurePersistenceService>(persistence);

        di.registerSingleton<AccountJson>(MockAccountJson());

        final ops = MockAccountOps();
        di.registerSingleton<AccountOps>(ops);

        final subject = AccountStore();

        await expectLater(subject.load(trace), throwsException);
      });
    });

    test("fetchWillReturnErrorWhenNoLoadCalledBefore", () async {
      await withTrace((trace) async {
        final subject = AccountStore();

        await expectLater(
            subject.fetch(trace), throwsA(isA<AccountNotInitialized>()));
      });
    });

    test("restoreWillThrowOnInvalidAccountId", () async {
      await withTrace((trace) async {
        final subject = AccountStore();

        // Empty account ID
        await expectLater(
            subject.restore(trace, ""), throwsA(isA<InvalidAccountId>()));
      });
    });

    // test("will generate new keypair on empty cache", () async {
    //   final mCache = MockSecurePersistenceSpec();
    //   when(mCache.loadOrThrow(any, any)).thenAnswer((_) =>
    //       Future.value(jsonDecode(Fixtures.cacheAccount))
    //   );
    //   di.registerSingleton<SecurePersistenceSpec>(mCache);
    //
    //   final mKeypair = MockKeypairService();
    //   when(mKeypair.generate()).thenAnswer((_) =>
    //       Future.value(AccountKeypair("pub", "priv"))
    //   );
    //   di.registerSingleton<KeypairService>(mKeypair);
    //
    //   di.registerSingleton<ApiSpec>(MockApiSpec());
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
      await withTrace((trace) async {
        final ops = MockAccountOps();
        di.registerSingleton<AccountOps>(ops);

        final persistence = MockSecurePersistenceService();
        di.registerSingleton<SecurePersistenceService>(persistence);

        final store = AccountStore();
        di.registerSingleton<AccountStore>(store);

        final subject = AccountBinder.forTesting();

        await store.propose(
            trace, JsonAccount.fromJson(jsonDecode(fixtureJsonAccount2)));

        verify(ops.doAccountChanged(any)).called(1);
      });
    });

    test("onRestoreAccount", () async {
      await withTrace((trace) async {
        final store = MockAccountStore();
        di.registerSingleton<AccountStore>(store);

        final json = MockAccountJson();
        when(json.getAccount(any, "mocked2")).thenAnswer((_) => Future.value(
            JsonAccount.fromJson(jsonDecode(fixtureJsonAccount2))));
        di.registerSingleton<AccountJson>(json);

        final subject = AccountBinder.forTesting();

        await subject.onRestoreAccount("mocked2");

        verify(store.restore(any, any)).called(1);
      });
    });
  });

  group("binderErrors", () {
    test("onRestoreAccountWillShowModalOnFail", () async {
      await withTrace((trace) async {
        final persistence = MockSecurePersistenceService();
        di.registerSingleton<SecurePersistenceService>(persistence);

        final store = MockAccountStore();
        when(store.restore(any, any))
            .thenThrow(Exception("not a proper account id"));
        di.registerSingleton<AccountStore>(store);

        final stage = MockStageStore();
        di.registerSingleton<StageStore>(stage);

        final subject = AccountBinder.forTesting();

        await subject.onRestoreAccount("");

        verify(stage.showModalNow(any, any)).called(1);
      });
    });
  });
}
