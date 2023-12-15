import 'package:common/util/act.dart';
import 'package:mocktail/mocktail.dart';

import '../util/di.dart';
import 'channel.pg.dart';

class MockLinkOps extends Mock implements LinkOps {}

LinkOps getOps(Act act) {
  if (act.isProd()) {
    return LinkOps();
  }

  final ops = MockLinkOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockLinkOps ops) {
  when(() => ops.doLinksChanged(any())).thenAnswer(ignore());
}
