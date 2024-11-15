import 'package:mocktail/mocktail.dart';

import 'package:common/core/core.dart';
import 'channel.pg.dart';

class MockCommandOps extends Mock implements CommandOps {}

CommandOps getOps(Act act) {
  if (act.isProd()) {
    return CommandOps();
  }

  final ops = MockCommandOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockCommandOps ops) {
  when(() => ops.doCanAcceptCommands()).thenAnswer(ignore());
}
