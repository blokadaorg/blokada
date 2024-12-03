import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockDeviceOps extends Mock implements DeviceOps {}

DeviceOps getOps() {
  if (Core.act.isProd) {
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
  when(() => ops.doSafeSearchEnabled(any())).thenAnswer(ignore());
  when(() => ops.doDeviceAliasChanged(any())).thenAnswer(ignore());
}
