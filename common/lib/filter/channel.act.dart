import 'package:common/filter/channel.pg.dart';
import 'package:common/util/act.dart';
import 'package:common/util/di.dart';
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
