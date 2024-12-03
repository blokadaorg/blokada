import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockAccountOps extends Mock implements AccountOps {}

AccountOps getOps() {
  if (Core.act.isProd) {
    return AccountOps();
  }

  final ops = MockAccountOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockAccountOps ops) {
  registerFallbackValue(fixtureInactiveAccount);

  when(() => ops.doAccountChanged(any())).thenAnswer(ignore());
}

final fixtureInactiveAccount = Account(
  id: 'mockedmocked',
  activeUntil: '',
  active: false,
  type: 'libre',
  paymentSource: '',
);
