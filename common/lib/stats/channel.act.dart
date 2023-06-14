import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockStatsOps extends Mock implements StatsOps {}

StatsOps getOps(Act act) {
  if (act.isProd()) {
    return StatsOps();
  }

  final ops = MockStatsOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockStatsOps ops) {
  when(() => ops.doBlockedCounterChanged(any())).thenAnswer(ignore());
}
