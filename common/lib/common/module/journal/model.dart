part of 'journal.dart';

class UiJournalEntry {
  final String deviceName;
  final String domainName;
  final UiJournalAction action;
  final String listId;
  final String? profileId;
  final DateTime timestamp;
  final int requests;
  final bool modified;

  late String timestampText;

  UiJournalEntry({
    required this.deviceName,
    required this.domainName,
    required this.action,
    required this.listId,
    required this.profileId,
    required this.timestamp,
    this.requests = 1,
    this.modified = false,
  });

  static UiJournalEntry fromJsonEntry(JsonJournalEntry entry, bool modified) {
    return UiJournalEntry(
      deviceName: entry.deviceName,
      domainName: entry.domainName,
      action: _fromString(entry.action),
      listId: entry.list,
      profileId: entry.profile,
      timestamp: DateTime.parse(entry.timestamp),
      modified: modified,
    );
  }

  bool isBlocked() {
    return action == UiJournalAction.block;
  }
}

enum UiJournalAction {
  allow,
  block,
}

UiJournalAction _fromString(String action) {
  switch (action) {
    case "block":
      return UiJournalAction.block;
    default:
      return UiJournalAction.allow;
  }
}

enum JournalFilterType { all, blocked, passed }

class JournalFilter {
  final JournalFilterType showOnly;
  final String searchQuery; // Empty string means "no query"
  final String deviceName; // Empty string means "all devices"
  final bool sortNewestFirst;

  JournalFilter({
    required this.showOnly,
    required this.searchQuery,
    required this.deviceName,
    required this.sortNewestFirst,
  });

  // Providing null means "no change" (existing filter is used)
  // To reset a query/device, provide an empty string.
  JournalFilter updateOnly({
    JournalFilterType? showOnly,
    String? searchQuery,
    String? deviceName,
    bool? sortNewestFirst,
  }) {
    return JournalFilter(
      showOnly: showOnly ?? this.showOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      deviceName: deviceName ?? this.deviceName,
      sortNewestFirst: sortNewestFirst ?? this.sortNewestFirst,
    );
  }

  List<UiJournalEntry> apply(List<UiJournalEntry> entries) {
    List<UiJournalEntry> filtered = entries;

    // Apply search term
    final q = searchQuery;
    if (q.length > 1) {
      filtered = filtered.where((e) => e.domainName.contains(q)).toList();
    }

    // Apply device
    final d = deviceName;
    if (!Core.act.isFamily && d.isNotEmpty) {
      filtered = filtered.where((e) => e.deviceName == deviceName).toList();
    }

    // Apply filtering
    if (showOnly == JournalFilterType.blocked) {
      filtered =
          filtered.where((e) => e.action == UiJournalAction.block).toList();
    } else if (showOnly == JournalFilterType.passed) {
      filtered =
          filtered.where((e) => e.action == UiJournalAction.allow).toList();
    }

    // Apply sorting
    if (sortNewestFirst) {
      // It should be OK to sort ISO timestamps as strings
      filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      filtered.sort((a, b) => b.requests.compareTo(a.requests));
    }

    return filtered;
  }
}

class UiJournalMainEntry {
  final String domainName;
  final int requests;
  final UiJournalAction action;
  final String? listId;

  UiJournalMainEntry({
    required this.domainName,
    required this.requests,
    required this.action,
    this.listId,
  });
}
