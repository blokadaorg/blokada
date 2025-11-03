part of 'journal.dart';

final _noFilter = JournalFilter(
  showOnly: JournalFilterType.all,
  searchQuery: "", // Empty string means "no query"
  deviceName: "", // Empty string means "all devices"
  sortNewestFirst: true,
  exactMatch: false,
);

class JournalActor with Logging, Actor {
  late final _api = Core.get<JournalApi>();
  late final _customlist = Core.get<CustomListsValue>();

  late final filteredEntries = Core.get<JournalEntriesValue>();
  late final filter = Core.get<JournalFilterValue>();

  late final devices = Core.get<JournalDevicesValue>();

  List<UiJournalEntry> allEntries = [];
  bool isLoadingMore = false;
  bool hasMoreData = true;
  String? lastLoadedTimestamp;

  fetch(Marker m, {DeviceTag? tag, bool append = false}) async {
    await log(m).trace("fetch", (m) async {
      // Check if we can proceed with pagination
      if (append && (!hasMoreData || isLoadingMore)) {
        return;
      }

      if (Core.act.isFamily && tag == null) {
        throw Exception("Family must provide a tag");
      }

      if (append) {
        isLoadingMore = true;
      }

      try {
        final currentFilter = filter.now;
        final domainParam =
            _normalizeDomainQuery(currentFilter.searchQuery, currentFilter.exactMatch);
        final deviceParam = _normalizeDeviceName(currentFilter.deviceName);
        final actionParam = _mapActionParam(currentFilter.showOnly);

        // Determine start parameter for pagination
        String? start = append ? lastLoadedTimestamp : null;

        List<JsonJournalEntry> entries;
        if (Core.act.isFamily) {
          entries = await _api.fetch(
            m,
            tag!,
            start: start,
            domain: domainParam,
            action: actionParam,
            deviceName: deviceParam,
          );
        } else {
          entries = await _api.fetchForV6(
            m,
            start: start,
            domain: domainParam,
            action: actionParam,
            deviceName: deviceParam,
          );
        }

        // If filter changed while waiting for response, drop outdated data
        if (!identical(currentFilter, filter.now)) {
          return;
        }

        // If no entries returned, we've reached the end
        if (entries.isEmpty) {
          hasMoreData = false;
          if (!append) {
            allEntries = [];
            filteredEntries.now = currentFilter.apply(allEntries);
            lastLoadedTimestamp = null;
          }
          if (append) {
            isLoadingMore = false;
          }
          return;
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
        // Keep previously discovered devices when using server-side filters
        Set<String> deviceNames = Set.from(devices.now);
        if (!append && deviceParam == null) {
          deviceNames.clear();
        }
        for (var entry in grouped) {
          entry.timestampText = timeago.format(entry.timestamp);

          if (entry.deviceName.isNotBlank) {
            deviceNames.add(entry.deviceName);
          }
        }
        devices.now = deviceNames;

        // Update entries and pagination state
        if (append) {
          allEntries.addAll(grouped);
          // Update cursor to the timestamp of the last (oldest) entry
          if (grouped.isNotEmpty) {
            lastLoadedTimestamp = grouped.last.timestamp.toIso8601String();
          }
        } else {
          allEntries = grouped;
          // Reset pagination state on full refresh
          hasMoreData = true;
          if (grouped.isNotEmpty) {
            lastLoadedTimestamp = grouped.last.timestamp.toIso8601String();
          } else {
            lastLoadedTimestamp = null;
          }
        }

        filteredEntries.now = currentFilter.apply(allEntries);
      } finally {
        if (append) {
          isLoadingMore = false;
        }
      }
    });
  }

  clear() {
    allEntries = [];
    filteredEntries.now = [];
    hasMoreData = true;
    lastLoadedTimestamp = null;
    isLoadingMore = false;
  }

  UiJournalMainEntry getMainEntry(UiJournalEntry entry) {
    // Extract TLD-level domain (e.g., "ads.apple.com" -> "apple.com")
    String mainDomain = _extractMainDomain(entry.domainName);

    // Find exact match for the main domain with same action
    final exactMatch = allEntries.firstWhereOrNull(
      (e) => e.domainName == mainDomain && e.action == entry.action
    );

    // Use exact match data if found, otherwise use defaults
    return UiJournalMainEntry(
      domainName: mainDomain,
      requests: exactMatch?.requests ?? 0,
      action: entry.action,
      listId: exactMatch?.listId,
    );
  }

  List<UiJournalEntry> getSubdomainEntries(UiJournalMainEntry mainEntry) {
    // Filter for subdomains with matching action only
    final filteredEntries = allEntries.where((entry) =>
      entry.domainName != mainEntry.domainName &&
      entry.domainName.endsWith('.${mainEntry.domainName}') &&
      entry.action == mainEntry.action
    );

    // Group by domainName and sum up requests
    final Map<String, UiJournalEntry> aggregatedEntries = {};

    for (final entry in filteredEntries) {
      final domainName = entry.domainName;
      if (aggregatedEntries.containsKey(domainName)) {
        // Sum up requests for the same domain
        final existing = aggregatedEntries[domainName]!;
        aggregatedEntries[domainName] = UiJournalEntry(
          deviceName: existing.deviceName,
          domainName: existing.domainName,
          action: existing.action,
          listId: existing.listId,
          profileId: existing.profileId,
          timestamp: existing.timestamp,
          requests: existing.requests + entry.requests,
          modified: existing.modified,
        );
      } else {
        // First occurrence of this domain
        aggregatedEntries[domainName] = entry;
      }
    }

    // Convert to list and sort by domainName
    final result = aggregatedEntries.values.toList();
    result.sort((a, b) => a.domainName.compareTo(b.domainName));

    return result;
  }

  String _extractMainDomain(String domain) {
    // Simple TLD extraction - splits by dots and takes last 2 parts
    // e.g., "ads.apple.com" -> "apple.com"
    List<String> parts = domain.split('.');
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
    }
    return domain; // Return as-is if already a main domain
  }

  bool _decideModified(String domainName, UiJournalAction action,
      List<CustomListEntry> allowed, List<CustomListEntry> denied, bool wasException) {
    final isOnAllowed = allowed.any((e) => e.domainName == domainName);
    final isOnDenied = denied.any((e) => e.domainName == domainName);
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

  String? _mapActionParam(JournalFilterType showOnly) {
    switch (showOnly) {
      case JournalFilterType.blocked:
        return "block";
      case JournalFilterType.passed:
        return "allow";
      case JournalFilterType.all:
      default:
        return null;
    }
  }

  String? _normalizeDomainQuery(String query, bool exactMatch) {
    final trimmed = query.trim();
    if (trimmed.length <= 1) return null;
    final normalized = trimmed;
    if (exactMatch) return normalized;
    return '*$normalized*';
  }

  String? _normalizeDeviceName(String deviceName) {
    final trimmed = deviceName.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}
