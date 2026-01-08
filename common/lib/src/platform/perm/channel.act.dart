import 'package:common/src/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockPermOps extends Mock implements PermOps {}

PermOps getOps() {
  if (Core.act.isProd) {
    return PermOps();
  }

  final ops = MockPermOps();
  _actAllPermsEnabled(ops);
  return ops;
}

_actAllPermsEnabled(MockPermOps ops) {
  when(() => ops.doSetPrivateDnsEnabled(any(), any())).thenAnswer(ignore());
  when(() => ops.doAskNotificationPerms()).thenAnswer(ignore());
  when(() => ops.doAuthenticate()).thenAnswer((_) async {
    return true;
  });
  when(() => ops.doNotificationEnabled()).thenAnswer((_) async {
    return true;
  });
  when(() => ops.doVpnEnabled()).thenAnswer((_) async {
    return true;
  });
  when(() => ops.isRunningOnMac()).thenAnswer((_) async {
    return false;
  });
}
