import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockDeviceOps extends Mock implements DeviceOps {}

DeviceOps getOps(Act act) {
  if (act.isProd()) {
    return DeviceOps();
  }

  final ops = MockDeviceOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockDeviceOps ops) {
  when(() => ops.doCloudEnabled(any())).thenAnswer(ignore());
  when(() => ops.doRetentionChanged(any())).thenAnswer(ignore());
  when(() => ops.doDeviceTagChanged(any())).thenAnswer(ignore());
  when(() => ops.doNameProposalsChanged(any())).thenAnswer(ignore());
}
