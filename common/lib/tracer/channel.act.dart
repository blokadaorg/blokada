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
  when(() => ops.doStartFile(any(), any())).thenAnswer(ignore());
  when(() => ops.doSaveBatch(any(), any(), any())).thenAnswer(ignore());
  when(() => ops.doShareFile(any())).thenAnswer(ignore());
  when(() => ops.doFileExists(any())).thenAnswer((_) async => false);
  when(() => ops.doDeleteFile(any())).thenAnswer(ignore());
}
