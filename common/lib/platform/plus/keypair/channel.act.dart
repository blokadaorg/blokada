import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockPlusKeypairOps extends Mock implements PlusKeypairOps {}

PlusKeypairOps getOps() {
  if (Core.act.isProd) {
    return PlusKeypairOps();
  }

  final ops = MockPlusKeypairOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockPlusKeypairOps ops) {
  registerFallbackValue(PlusKeypair(publicKey: "mocked", privateKey: "mocked"));

  when(() => ops.doGenerateKeypair()).thenAnswer((_) async {
    return PlusKeypair(publicKey: "mock-pk", privateKey: "mock-sk");
  });
}
