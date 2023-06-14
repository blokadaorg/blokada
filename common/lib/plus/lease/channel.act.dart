import 'package:mocktail/mocktail.dart';

import '../../util/act.dart';
import '../../util/di.dart';
import 'channel.pg.dart';

class MockPlusLeaseOps extends Mock implements PlusLeaseOps {}

PlusLeaseOps getOps(Act act) {
  if (act.isProd()) {
    return PlusLeaseOps();
  }

  final ops = MockPlusLeaseOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockPlusLeaseOps ops) {
  when(() => ops.doLeasesChanged(any())).thenAnswer(ignore());
  when(() => ops.doCurrentLeaseChanged(any())).thenAnswer(ignore());
}
