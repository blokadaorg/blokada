import 'package:common/account/account.dart';
import 'package:common/persistence/persistence.dart';
import 'package:common/plus/keypair/channel.pg.dart';
import 'package:common/plus/keypair/keypair.dart';
import 'package:common/plus/plus.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
@GenerateNiceMocks([
  MockSpec<PlusKeypairStore>(),
  MockSpec<PlusKeypairOps>(),
  MockSpec<SecurePersistenceService>(),
  MockSpec<AccountStore>(),
  MockSpec<PlusStore>(),
])
import 'keypair_test.mocks.dart';

final _fixtureKeypair =
    PlusKeypair(publicKey: "publicKey", privateKey: "privateKey");

void main() {
  group("store", () {
    test("generate", () async {
      await withTrace((trace) async {
        final persistence = MockSecurePersistenceService();
        depend<SecurePersistenceService>(persistence);

        final ops = MockPlusKeypairOps();
        when(ops.doGenerateKeypair())
            .thenAnswer((_) => Future.value(_fixtureKeypair));
        depend<PlusKeypairOps>(ops);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        final plus = MockPlusStore();
        depend<PlusStore>(plus);

        final subject = PlusKeypairStore();
        verifyNever(ops.doGenerateKeypair());

        await subject.generate(trace);
        verify(ops.doGenerateKeypair()).called(1);
        verify(persistence.save(any, any, any)).called(1);
        expect(subject.currentKeypair, isNotNull);
      });
    });

    test("load", () async {
      await withTrace((trace) async {
        final ops = MockPlusKeypairOps();
        depend<PlusKeypairOps>(ops);

        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any)).thenAnswer((_) => Future.value(
            {"publicKey": "publicKey", "privateKey": "privateKey"}));
        depend<SecurePersistenceService>(persistence);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        final plus = MockPlusStore();
        depend<PlusStore>(plus);

        final subject = PlusKeypairStore();
        expect(subject.currentKeypair, null);

        await subject.load(trace);
        expect(subject.currentDevicePublicKey, "publicKey");
      });
    });

    test("loadWhenNoPersistence", () async {
      await withTrace((trace) async {
        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any))
            .thenThrow(Exception("not found"));
        depend<SecurePersistenceService>(persistence);

        final ops = MockPlusKeypairOps();
        when(ops.doGenerateKeypair())
            .thenAnswer((_) => Future.value(_fixtureKeypair));
        depend<PlusKeypairOps>(ops);

        final account = MockAccountStore();
        depend<AccountStore>(account);

        final plus = MockPlusStore();
        depend<PlusStore>(plus);

        final subject = PlusKeypairStore();

        await subject.load(trace);
        verify(ops.doGenerateKeypair()).called(1);
      });
    });
  });
}
