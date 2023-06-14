import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockAccountOps extends Mock implements AccountOps {}

AccountOps getOps(Act act) {
  if (act.isProd()) {
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
