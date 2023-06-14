import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockCustomOps extends Mock implements CustomOps {}

CustomOps getOps(Act act) {
  if (act.isProd()) {
    return CustomOps();
  }

  final ops = MockCustomOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockCustomOps ops) {
  when(() => ops.doCustomAllowedChanged(any())).thenAnswer(ignore());
  when(() => ops.doCustomDeniedChanged(any())).thenAnswer(ignore());
}
