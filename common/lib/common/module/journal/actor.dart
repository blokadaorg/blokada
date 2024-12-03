part of 'journal.dart';

final _noFilter = JournalFilter(
  showOnly: JournalFilterType.all,
  searchQuery: "", // Empty string means "no query"
  sortNewestFirst: true,
);

class JournalActor with Logging, Actor {
  late final _api = Core.get<JournalApi>();
  late final _custom = Core.get<CustomStore>();

  late final filteredEntries = Core.get<JournalEntriesValue>();
  late final filter = Core.get<JournalFilterValue>();

  List<UiJournalEntry> allEntries = [];

  fetch(Marker m, {DeviceTag? tag}) async {
    await log(m).trace("fetch", (m) async {
      if (Core.act.isFamily && tag == null) {
        throw Exception("Family must provide a tag");
      }

      List<JsonJournalEntry> entries;
      if (Core.act.isFamily) {
        entries = await _api.fetch(m, tag!);
      } else {
        entries = await _api.fetchForV6(m);
      }

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
      filteredEntries.now = filter.now.apply(allEntries);
      await _custom.fetch(m);
    });
  }
}
