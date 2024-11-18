import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockRateOps extends Mock implements RateOps {}

RateOps getOps(Act act) {
  if (act.isProd) {
    return RateOps();
  }

  final ops = MockRateOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockRateOps ops) {
  when(() => ops.doShowRateDialog()).thenAnswer(ignore());
}
