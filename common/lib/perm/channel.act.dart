import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockPermOps extends Mock implements PermOps {}

PermOps getOps(Act act) {
  if (act.isProd()) {
    return PermOps();
  }

  final ops = MockPermOps();
  _actAllPermsEnabled(ops);
  return ops;
}

_actAllPermsEnabled(MockPermOps ops) {
  when(() => ops.doSetSetPrivateDnsEnabled(any(), any())).thenAnswer(ignore());
  when(() => ops.doSetSetPrivateDnsForward()).thenAnswer(ignore());
  when(() => ops.doPrivateDnsEnabled(any(), any())).thenAnswer((_) async {
    return true;
  });
  when(() => ops.doNotificationEnabled()).thenAnswer((_) async {
    return true;
  });
  when(() => ops.doVpnEnabled()).thenAnswer((_) async {
    return true;
  });
}
