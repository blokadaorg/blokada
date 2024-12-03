import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockPlusGatewayOps extends Mock implements PlusGatewayOps {}

PlusGatewayOps getOps() {
  if (Core.act.isProd) {
    return PlusGatewayOps();
  }

  final ops = MockPlusGatewayOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockPlusGatewayOps ops) {
  when(() => ops.doGatewaysChanged(any())).thenAnswer(ignore());
  when(() => ops.doSelectedGatewayChanged(any())).thenAnswer(ignore());
}
