import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockAppStartOps extends Mock implements AppStartOps {}

AppStartOps getOps(Act act) {
  if (act.isProd) {
    return AppStartOps();
  }

  final ops = MockAppStartOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockAppStartOps ops) {
  when(() => ops.doAppPauseDurationChanged(any())).thenAnswer(ignore());
}
