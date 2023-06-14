import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockJournalOps extends Mock implements JournalOps {}

JournalOps getOps(Act act) {
  if (act.isProd()) {
    return JournalOps();
  }

  final ops = MockJournalOps();
  _actNormal(ops);
  return ops;
}

_actNormal(MockJournalOps ops) {
  registerFallbackValue(fixtureJournalFilter);

  when(() => ops.doReplaceEntries(any())).thenAnswer(ignore());
  when(() => ops.doFilterChanged(any())).thenAnswer(ignore());
  when(() => ops.doDevicesChanged(any())).thenAnswer(ignore());
  when(() => ops.doHistoricEntriesAvailable(any())).thenAnswer(ignore());
}

final fixtureJournalFilter = JournalFilter(
  showOnly: JournalFilterType.showAll,
  searchQuery: "",
  deviceName: "",
  sortNewestFirst: false,
);
