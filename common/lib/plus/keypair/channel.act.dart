import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import 'channel.pg.dart';

class MockPlusKeypairOps extends Mock implements PlusKeypairOps {}

PlusKeypairOps getOps(Act act) {
  if (act.isProd()) {
    return PlusKeypairOps();
  }

  final ops = MockPlusKeypairOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockPlusKeypairOps ops) {
  when(() => ops.doGenerateKeypair()).thenAnswer((_) async {
    return PlusKeypair(publicKey: "mock-pk", privateKey: "mock-sk");
  });
}
