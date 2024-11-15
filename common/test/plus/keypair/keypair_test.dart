import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/persistence/persistence.dart';
import 'package:common/platform/plus/keypair/channel.pg.dart';
import 'package:common/platform/plus/keypair/keypair.dart';
import 'package:common/platform/plus/plus.dart';
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
      await withTrace((m) async {
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

        await subject.generate(m);
        verify(ops.doGenerateKeypair()).called(1);
        verify(persistence.save(any, any, any)).called(1);
        expect(subject.currentKeypair, isNotNull);
      });
    });

    test("load", () async {
      await withTrace((m) async {
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

        await subject.load(m);
        expect(subject.currentDevicePublicKey, "publicKey");
      });
    });

    test("loadWhenNoPersistence", () async {
      await withTrace((m) async {
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

        await subject.load(m);
        verify(ops.doGenerateKeypair()).called(1);
      });
    });
  });
}
