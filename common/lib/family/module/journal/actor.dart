part of 'journal.dart';

final _noFilter = JournalFilter(
  showOnly: JournalFilterType.all,
  searchQuery: "", // Empty string means "no query"
  sortNewestFirst: true,
);

class JournalActor with Logging, Actor {
  late final _api = DI.get<JournalApi>();
  late final _custom = DI.get<CustomStore>();

  JournalFilter filter = _noFilter;
  List<UiJournalEntry> allEntries = [];
  List<UiJournalEntry> filteredEntries = [];

  Function() onChange = () {};

  fetch(DeviceTag tag, Marker m) async {
    await log(m).trace("fetch", (m) async {
      final entries = await _api.fetch(m, tag);
      final mapped =
          entries.map((e) => UiJournalEntry.fromJsonEntry(e)).toList();

      // Sort from the oldest
      mapped.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Group entries by same domainName if they are next to each other, and have the same action
      final grouped = <UiJournalEntry>[];
      for (var i = 0; i < mapped.length; i++) {
        final entry = mapped[i];
        if (grouped.isNotEmpty &&
            grouped.last.domainName == entry.domainName &&
            grouped.last.action == entry.action) {
          grouped.last = UiJournalEntry(
            deviceName: entry.deviceName,
            domainName: entry.domainName,
            action: entry.action,
            listId: entry.listId,
            profileId: entry.profileId,
            timestamp: entry.timestamp, // Most recent occurrence
            requests: grouped.last.requests + 1,
          );
        } else {
          grouped.add(entry);
        }
      }

      // Sort from the most recent first
      grouped.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Parse timestampText for every entry
      for (var entry in grouped) {
        entry.timestampText = timeago.format(entry.timestamp);
      }

      allEntries = grouped;
      filteredEntries = filter.apply(allEntries);

      await _custom.fetch(m);
      onChange();
    });
  }

  resetFilter() {
    filter = _noFilter;
  }
}
