import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockLinkOps extends Mock implements LinkOps {}

LinkOps getOps() {
  if (Core.act.isProd) {
    return LinkOps();
  }

  final ops = MockLinkOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockLinkOps ops) {
  when(() => ops.doLinksChanged(any())).thenAnswer(ignore());
}
