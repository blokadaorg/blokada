part of 'journal.dart';

final _noFilter = JournalFilter(
  showOnly: JournalFilterType.all,
  searchQuery: "", // Empty string means "no query"
  deviceName: "", // Empty string means "all devices"
  sortNewestFirst: true,
);

class JournalActor with Logging, Actor {
  late final _api = Core.get<JournalApi>();
  late final _customlist = Core.get<CustomListsValue>();

  late final filteredEntries = Core.get<JournalEntriesValue>();
  late final filter = Core.get<JournalFilterValue>();

  late final devices = Core.get<JournalDevicesValue>();

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

      final allowed = _customlist.now.allowed;
      final denied = _customlist.now.denied;

      final mapped = entries.map((e) {
        final entry = UiJournalEntry.fromJsonEntry(e, false);
        return UiJournalEntry.fromJsonEntry(
            e,
            _decideModified(entry.domainName, entry.action, allowed, denied,
                _wasException(entry.listId)));
      }).toList();

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
            modified: entry.modified,
          );
        } else {
          grouped.add(entry);
        }
      }

      // Sort from the most recent first
      grouped.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Parse timestampText for every entry
      // Also add device names
      Set<String> deviceNames = {};
      for (var entry in grouped) {
        entry.timestampText = timeago.format(entry.timestamp);

        if (entry.deviceName.isNotBlank) {
          deviceNames.add(entry.deviceName);
        }
      }
      devices.now = deviceNames;

      allEntries = grouped;
      filteredEntries.now = filter.now.apply(allEntries);
    });
  }

  clear() {
    allEntries = [];
    filteredEntries.now = [];
  }

  bool _decideModified(String domainName, UiJournalAction action,
      List<String> allowed, List<String> denied, bool wasException) {
    final isOnAllowed = allowed.contains(domainName);
    final isOnDenied = denied.contains(domainName);
    final wasAllowed = action == UiJournalAction.allow;
    final wasDenied = action == UiJournalAction.block;

    if ((isOnAllowed && wasDenied) || (isOnDenied && wasAllowed)) {
      return true;
    }

    if (wasException && !isOnAllowed && !isOnDenied) {
      return true;
    }

    return false;
  }

  bool _wasException(String listId) {
    // Actual lists are 32 chars
    // When list is user custom exceptions, its device id, which is shorter
    return listId.isNotEmpty && listId.length < 32;
  }
}
