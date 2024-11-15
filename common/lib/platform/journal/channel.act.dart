import 'package:common/core/core.dart';
import 'package:common/platform/journal/channel.pg.dart';
import 'package:mocktail/mocktail.dart';

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
  showOnly: JournalFilterType.all,
  searchQuery: "",
  deviceName: "",
  sortNewestFirst: false,
);
