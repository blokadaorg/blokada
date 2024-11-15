import 'package:common/core/core.dart';
import 'package:common/platform/filter/channel.pg.dart';
import 'package:mocktail/mocktail.dart';

class MockFilterOps extends Mock implements FilterOps {}

FilterOps getOps(Act act) {
  if (act.isProd()) {
    return FilterOps();
  }

  final ops = MockFilterOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockFilterOps ops) {
  when(() => ops.doFiltersChanged(any())).thenAnswer(ignore());
  when(() => ops.doFilterSelectionChanged(any())).thenAnswer(ignore());
  when(() => ops.doListToTagChanged(any())).thenAnswer(ignore());
}
