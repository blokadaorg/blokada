import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockFamilyOps extends Mock implements FamilyOps {}

FamilyOps getOps(Act act) {
  if (act.isProd()) {
    return FamilyOps();
  }

  final ops = MockFamilyOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockFamilyOps ops) {
  when(() => ops.doFamilyLinkTemplateChanged(any())).thenAnswer(ignore());
}
