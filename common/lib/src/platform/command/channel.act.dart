import 'package:common/src/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockCommandOps extends Mock implements CommandOps {}

CommandOps getOps() {
  // Mocked builds still run the native shell, which queues commands until
  // this tells it Flutter is ready.
  if (Core.act.isProd || Core.act.isMocked) {
    return CommandOps();
  }

  final ops = MockCommandOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockCommandOps ops) {
  when(() => ops.doCanAcceptCommands()).thenAnswer(ignore());
}
