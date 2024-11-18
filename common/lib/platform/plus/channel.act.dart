import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockPlusOps extends Mock implements PlusOps {}

PlusOps getOps(Act act) {
  if (act.isProd) {
    return PlusOps();
  }

  final ops = MockPlusOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockPlusOps ops) {
  when(() => ops.doPlusEnabledChanged(any())).thenAnswer(ignore());
}
