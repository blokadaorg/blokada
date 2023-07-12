import 'package:pigeon/pigeon.dart';

class JournalEntry {
  final String domainName;
  final JournalEntryType type;
  final String time;
  final int requests;
  final String deviceName;
  final String? list;

  JournalEntry(this.domainName, this.type, this.time, this.requests,
      this.deviceName, this.list);
}

enum JournalEntryType {
  passed, // Just ordinary case of allowing the request
  blocked, // Blocked because it's on any of our lists
  blockedDenied, // Blocked because it's on user's personal Denied list
  passedAllowed, // Passed because it's on user's personal Allowed list
}

enum JournalFilterType { all, blocked, passed }

class JournalFilter {
  final JournalFilterType showOnly;
  final String searchQuery; // Empty string means "no query"
  final String deviceName; // Empty string means "all devices"
  final bool sortNewestFirst;

  JournalFilter(
      this.showOnly, this.searchQuery, this.deviceName, this.sortNewestFirst);
}

@HostApi()
abstract class JournalOps {
  @async
  void doReplaceEntries(List<JournalEntry> entries);

  @async
  void doFilterChanged(JournalFilter filter);

  @async
  void doDevicesChanged(List<String> devices);

  @async
  // Called whenever user is scrolling down and more entries are available.
  void doHistoricEntriesAvailable(List<JournalEntry> entries);
}
