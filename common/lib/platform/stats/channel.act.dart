import 'package:common/core/core.dart';
import 'package:mocktail/mocktail.dart';

import 'channel.pg.dart';

class MockStatsOps extends Mock implements StatsOps {}

StatsOps getOps() {
  if (Core.act.isProd) {
    return StatsOps();
  }

  final ops = MockStatsOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockStatsOps ops) {
  when(() => ops.doBlockedCounterChanged(any())).thenAnswer(ignore());
}
