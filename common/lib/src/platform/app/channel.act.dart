import 'package:common/src/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockAppOps extends Mock implements AppOps {}

AppOps getOps() {
  if (Core.act.isProd) {
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
