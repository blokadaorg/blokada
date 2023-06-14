import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockDeckOps extends Mock implements DeckOps {}

DeckOps getOps(Act act) {
  if (act.isProd()) {
    return DeckOps();
  }

  final ops = MockDeckOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockDeckOps ops) {
  when(() => ops.doDecksChanged(any())).thenAnswer(ignore());
}
