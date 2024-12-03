import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/plus/keypair/channel.pg.dart';
import 'package:common/platform/plus/keypair/keypair.dart';
import 'package:common/platform/plus/plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';
@GenerateNiceMocks([
  MockSpec<PlusKeypairStore>(),
  MockSpec<PlusKeypairOps>(),
  MockSpec<Persistence>(),
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
        final persistence = MockPersistence();
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final ops = MockPlusKeypairOps();
        when(ops.doGenerateKeypair())
            .thenAnswer((_) => Future.value(_fixtureKeypair));
        Core.register<PlusKeypairOps>(ops);

        final account = MockAccountStore();
        Core.register<AccountStore>(account);

        final plus = MockPlusStore();
        Core.register<PlusStore>(plus);

        final subject = PlusKeypairStore();
        verifyNever(ops.doGenerateKeypair());

        await subject.generate(m);
        verify(ops.doGenerateKeypair()).called(1);
        verify(persistence.saveJson(any, any, any)).called(1);
        expect(subject.currentKeypair, isNotNull);
      });
    });

    test("load", () async {
      await withTrace((m) async {
        final ops = MockPlusKeypairOps();
        Core.register<PlusKeypairOps>(ops);

        final persistence = MockPersistence();
        when(persistence.loadJson(any, any)).thenAnswer((_) => Future.value(
            {"publicKey": "publicKey", "privateKey": "privateKey"}));
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final account = MockAccountStore();
        Core.register<AccountStore>(account);

        final plus = MockPlusStore();
        Core.register<PlusStore>(plus);

        final subject = PlusKeypairStore();
        expect(subject.currentKeypair, null);

        await subject.load(m);
        expect(subject.currentDevicePublicKey, "publicKey");
      });
    });

    test("loadWhenNoPersistence", () async {
      await withTrace((m) async {
        final persistence = MockPersistence();
        when(persistence.loadJson(any, any)).thenThrow(Exception("not found"));
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final ops = MockPlusKeypairOps();
        when(ops.doGenerateKeypair())
            .thenAnswer((_) => Future.value(_fixtureKeypair));
        Core.register<PlusKeypairOps>(ops);

        final account = MockAccountStore();
        Core.register<AccountStore>(account);

        final plus = MockPlusStore();
        Core.register<PlusStore>(plus);

        final subject = PlusKeypairStore();

        await subject.load(m);
        verify(ops.doGenerateKeypair()).called(1);
      });
    });
  });
}
