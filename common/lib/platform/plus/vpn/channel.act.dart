import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockPlusVpnOps extends Mock implements PlusVpnOps {}

PlusVpnOps getOps() {
  if (Core.act.isProd) {
    return PlusVpnOps();
  }

  final ops = MockPlusVpnOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockPlusVpnOps ops) {
  registerFallbackValue(fixtureVpnConfig);

  when(() => ops.doSetVpnConfig(any())).thenAnswer(ignore());
  when(() => ops.doSetVpnActive(any())).thenAnswer(ignore());
}

final fixtureVpnConfig = VpnConfig(
  devicePrivateKey: 'devicePrivateKey',
  deviceTag: 'deviceTag',
  gatewayPublicKey: 'gatewayPublicKey',
  gatewayNiceName: 'gatewayNiceName',
  gatewayIpv4: 'gatewayIpv4',
  gatewayIpv6: 'gatewayIpv6',
  gatewayPort: 'gatewayPort',
  leaseVip4: 'leaseVip4',
  leaseVip6: 'leaseVip6',
);
