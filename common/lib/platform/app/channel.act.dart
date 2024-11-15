import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockAppOps extends Mock implements AppOps {}

AppOps getOps(Act act) {
  if (act.isProd()) {
    return AppOps();
  }

  final ops = MockAppOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockAppOps ops) {
  registerFallbackValue(AppStatus.unknown);

  when(() => ops.doAppStatusChanged(any())).thenAnswer((_) async {});
}
