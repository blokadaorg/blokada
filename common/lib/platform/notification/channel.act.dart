import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockNotificationOps extends Mock implements NotificationOps {}

NotificationOps getOps(Act act) {
  if (act.isProd()) {
    return NotificationOps();
  }

  final ops = MockNotificationOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockNotificationOps ops) {
  when(() => ops.doShow(any(), any(), any())).thenAnswer(ignore());
  when(() => ops.doDismissAll()).thenAnswer(ignore());
}
