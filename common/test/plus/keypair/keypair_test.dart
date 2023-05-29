import 'package:common/env/env.dart';
import 'package:common/event.dart';
import 'package:common/persistence/persistence.dart';
import 'package:common/plus/keypair/channel.pg.dart';
import 'package:common/plus/keypair/keypair.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
@GenerateNiceMocks([
  MockSpec<EventBus>(),
  MockSpec<PlusKeypairStore>(),
  MockSpec<PlusKeypairOps>(),
  MockSpec<SecurePersistenceService>(),
])
import 'keypair_test.mocks.dart';

final _fixtureKeypair =
    PlusKeypair(publicKey: "publicKey", privateKey: "privateKey");

void main() {
  group("store", () {
    test("generate", () async {
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final persistence = MockSecurePersistenceService();
        depend<SecurePersistenceService>(persistence);

        final ops = MockPlusKeypairOps();
        when(ops.doGenerateKeypair())
            .thenAnswer((_) => Future.value(_fixtureKeypair));
        depend<PlusKeypairOps>(ops);

        final env = EnvStore();
        depend<EnvStore>(env);

        final subject = PlusKeypairStore();
        verifyNever(ops.doGenerateKeypair());

        await subject.generate(trace);
        verify(ops.doGenerateKeypair()).called(1);
        verify(persistence.save(any, any, any)).called(1);
        expect(subject.currentKeypair, isNotNull);
        expect(env.devicePublicKey, "publicKey");
      });
    });

    test("load", () async {
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any)).thenAnswer((_) => Future.value(
            {"publicKey": "publicKey", "privateKey": "privateKey"}));
        depend<SecurePersistenceService>(persistence);

        final env = EnvStore();
        depend<EnvStore>(env);

        final subject = PlusKeypairStore();
        expect(env.devicePublicKey, null);

        await subject.load(trace);
        expect(env.devicePublicKey, "publicKey");
      });
    });

    test("loadWhenNoPersistence", () async {
      await withTrace((trace) async {
        final event = MockEventBus();
        depend<EventBus>(event);

        final persistence = MockSecurePersistenceService();
        when(persistence.loadOrThrow(any, any))
            .thenThrow(Exception("not found"));
        depend<SecurePersistenceService>(persistence);

        final ops = MockPlusKeypairOps();
        when(ops.doGenerateKeypair())
            .thenAnswer((_) => Future.value(_fixtureKeypair));
        depend<PlusKeypairOps>(ops);

        final env = EnvStore();
        depend<EnvStore>(env);

        final subject = PlusKeypairStore();

        await subject.load(trace);
        verify(ops.doGenerateKeypair()).called(1);
      });
    });
  });
}
