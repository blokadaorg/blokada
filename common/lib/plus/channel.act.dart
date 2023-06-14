import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockPlusOps extends Mock implements PlusOps {}

PlusOps getOps(Act act) {
  if (act.isProd()) {
    return PlusOps();
  }

  final ops = MockPlusOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockPlusOps ops) {
  when(() => ops.doPlusEnabledChanged(any())).thenAnswer(ignore());
}
