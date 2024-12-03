import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockEnvOps extends Mock implements EnvOps {}

EnvOps getOps() {
  if (Core.act.isProd) {
    return EnvOps();
  }

  final ops = MockEnvOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockEnvOps ops) {
  when(() => ops.doGetEnvPayload()).thenAnswer((_) {
    return Future.value(EnvPayload(
      appVersion: "6.0.0",
      osVersion: "ios",
      buildFlavor: "six",
      buildType: "mocked",
      cpu: "sim",
      deviceBrand: "iphone",
      deviceModel: "14",
      deviceName: "My iPhone",
    ));
  });

  when(() => ops.doUserAgentChanged(any())).thenAnswer(ignore());
}
