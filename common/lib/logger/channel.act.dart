import 'package:common/util/act.dart';
import 'package:common/util/di.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockLoggerOps extends Mock implements LoggerOps {}

LoggerOps getOps(Act act) {
  if (act.isProd()) {
    return LoggerOps();
  }

  final ops = MockLoggerOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockLoggerOps ops) {
  when(() => ops.doUseFilename(any())).thenAnswer(ignore());
  when(() => ops.doSaveBatch(any())).thenAnswer(ignore());
  when(() => ops.doShareFile()).thenAnswer(ignore());
}
