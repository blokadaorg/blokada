part of "journal.dart";

class JournalEntriesValue extends Value<List<UiJournalEntry>> {
  JournalEntriesValue() : super(load: () => []);
}

class JournalFilterValue extends Value<JournalFilter> {
  JournalFilterValue() : super(load: () => _noFilter);

  reset() => now = _noFilter;
}

class JournalDevicesValue extends Value<Set<String>> {
  JournalDevicesValue() : super(load: () => {});
}

class JournalRefreshValue extends Value<int> {
  JournalRefreshValue() : super(load: () => 0);
}
