import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/features/plus/domain/keypair/keypair.dart';
import 'package:common/src/features/plus/domain/plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../../tools.dart';
@GenerateNiceMocks([
  MockSpec<KeypairActor>(),
  MockSpec<KeypairChannel>(),
  MockSpec<Persistence>(),
  MockSpec<AccountStore>(),
  MockSpec<PlusActor>(),
])
import 'keypair_test.mocks.dart';

final _fixtureKeypair =
    Keypair(publicKey: "publicKey", privateKey: "privateKey");

void main() {
  group("store", () {
    test("generate", () async {
      await withTrace((m) async {
        final persistence = MockPersistence();
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final currentKeypair = CurrentKeypairValue();
        Core.register(currentKeypair);

        Core.register(PublicKeyProvidedValue());

        final ops = MockKeypairChannel();
        when(ops.doGenerateKeypair())
            .thenAnswer((_) => Future.value(_fixtureKeypair));
        Core.register<KeypairChannel>(ops);

        final account = MockAccountStore();
        Core.register<AccountStore>(account);

        final plus = MockPlusActor();
        Core.register<PlusActor>(plus);

        final subject = KeypairActor();
        verifyNever(ops.doGenerateKeypair());

        await subject.generate(m);
        verify(ops.doGenerateKeypair()).called(1);
        verify(persistence.save(any, any, any)).called(1);
        expect(currentKeypair.present, isNotNull);
      });
    });

    test("load", () async {
      await withTrace((m) async {
        final ops = MockKeypairChannel();
        Core.register<KeypairChannel>(ops);

        Core.register(PublicKeyProvidedValue());

        final persistence = MockPersistence();
        when(persistence.load(any, any)).thenAnswer((_) => Future.value(
            '{"publicKey": "publicKey", "privateKey": "privateKey"}'));
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final currentKeypair = CurrentKeypairValue();
        Core.register(currentKeypair);

        final account = MockAccountStore();
        Core.register<AccountStore>(account);

        final plus = MockPlusActor();
        Core.register<PlusActor>(plus);

        final subject = KeypairActor();
        expect(currentKeypair.present, null);

        await subject.load(m);
        expect(currentKeypair.present!.publicKey, "publicKey");
      });
    });

    test("loadWhenNoPersistence", () async {
      await withTrace((m) async {
        final persistence = MockPersistence();
        when(persistence.load(any, any)).thenThrow(Exception("not found"));
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        Core.register(PublicKeyProvidedValue());

        final ops = MockKeypairChannel();
        when(ops.doGenerateKeypair())
            .thenAnswer((_) => Future.value(_fixtureKeypair));
        Core.register<KeypairChannel>(ops);

        final currentKeypair = CurrentKeypairValue();
        Core.register(currentKeypair);

        final account = MockAccountStore();
        Core.register<AccountStore>(account);

        final plus = MockPlusActor();
        Core.register<PlusActor>(plus);

        final subject = KeypairActor();

        await subject.load(m);
        verify(ops.doGenerateKeypair()).called(1);
      });
    });
  });
}
