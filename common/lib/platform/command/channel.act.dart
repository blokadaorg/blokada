import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockCommandOps extends Mock implements CommandOps {}

CommandOps getOps() {
  if (Core.act.isProd) {
    return CommandOps();
  }

  final ops = MockCommandOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockCommandOps ops) {
  when(() => ops.doCanAcceptCommands()).thenAnswer(ignore());
}
