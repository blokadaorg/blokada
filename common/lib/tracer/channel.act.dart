import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockTracerOps extends Mock implements TracerOps {}

TracerOps getOps(Act act) {
  if (act.isProd()) {
    return TracerOps();
  }

  final ops = MockTracerOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockTracerOps ops) {
  when(() => ops.doStartFile(any())).thenAnswer(ignore());
  when(() => ops.doSaveBatch(any(), any())).thenAnswer(ignore());
}
