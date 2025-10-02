part of 'customlist.dart';

class CustomListEntry {
  final String domainName;
  final bool wildcard;

  CustomListEntry({required this.domainName, required this.wildcard});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomListEntry &&
          runtimeType == other.runtimeType &&
          domainName == other.domainName &&
          wildcard == other.wildcard;

  @override
  int get hashCode => domainName.hashCode ^ wildcard.hashCode;
}

class CustomLists {
  final List<CustomListEntry> denied;
  final List<CustomListEntry> allowed;

  CustomLists({required this.denied, required this.allowed});
}

class CustomlistActor with Actor, Logging {
  late final _customlist = Core.get<CustomlistApi>();
  late final _payload = Core.get<CustomListsValue>();

  String? profileId;

  // Has to be called before other methods
  setProfileId(String id, Marker m) async {
    if (profileId == id) return;
    profileId = id;
    _payload.reset();
    await fetch(m);
  }

  fetch(Marker m) async {
    if (profileId == null) log(m).t("Fetching customlist without profileId");

    final entries = await _customlist.fetchForProfile(m, profileId: profileId);

    print("CustomlistActor.fetch: Received ${entries.length} entries from API");
    for (var e in entries) {
      print("  - domain=${e.domainName}, action=${e.action.name}, wildcard=${e.wildcard}");
    }

    final denied = entries
        .where((e) => e.action == JsonCustomListAction.block)
        .map((e) => CustomListEntry(domainName: e.domainName, wildcard: e.wildcard))
        .toList();
    denied.sort((a, b) => a.domainName.compareTo(b.domainName));

    final allowed = entries
        .where((e) => e.action == JsonCustomListAction.allow)
        .map((e) => CustomListEntry(domainName: e.domainName, wildcard: e.wildcard))
        .toList();
    allowed.sort((a, b) => a.domainName.compareTo(b.domainName));

    _payload.now = CustomLists(denied: denied, allowed: allowed);
  }

  _allow(String domain, bool wildcard, Marker m) async {
    _payload.now = CustomLists(
      denied: _payload.now.denied,
      allowed: _payload.now.allowed..add(CustomListEntry(domainName: domain, wildcard: wildcard)),
    );

    await _customlist.add(
        m,
        JsonCustomList(
          domainName: domain,
          action: JsonCustomListAction.allow,
          wildcard: wildcard,
        ),
        profileId: profileId);
  }

  _deny(String domain, bool wildcard, Marker m) async {
    _payload.now = CustomLists(
      denied: _payload.now.denied..add(CustomListEntry(domainName: domain, wildcard: wildcard)),
      allowed: _payload.now.allowed,
    );

    await _customlist.add(
      m,
      JsonCustomList(
        domainName: domain,
        action: JsonCustomListAction.block,
        wildcard: wildcard,
      ),
      profileId: profileId,
    );
  }

  _delete(String domain, bool wildcard, Marker m) async {
    final entry = CustomListEntry(domainName: domain, wildcard: wildcard);
    _payload.now = CustomLists(
      denied: _payload.now.denied..remove(entry),
      allowed: _payload.now.allowed..remove(entry),
    );

    await _customlist.delete(
      m,
      JsonCustomList(
        domainName: domain,
        action: JsonCustomListAction.allow, // Ignored
        wildcard: wildcard,
      ),
      profileId: profileId,
    );
  }

  addOrRemove(String domain, bool wildcard, Marker m, {required bool gotBlocked}) async {
    if (contains(domain, wildcard: wildcard)) {
      await _delete(domain, wildcard, m);
    } else if (gotBlocked) {
      await _allow(domain, wildcard, m);
    } else {
      await _deny(domain, wildcard, m);
    }
    await fetch(m);
  }

  remove(Marker m, String domain, bool wildcard) async {
    await _delete(domain, wildcard, m);
    await fetch(m);
  }

  toggle(Marker m, String domain, bool wildcard) async {
    final allow = _payload.now.denied.any((e) => e.domainName == domain && e.wildcard == wildcard);
    if (allow) {
      await _allow(domain, wildcard, m);
    } else {
      await _deny(domain, wildcard, m);
    }
    await fetch(m);
  }

  bool contains(String domain, {bool? wildcard}) {
    if (wildcard != null) {
      return _payload.now.allowed.any((e) => e.domainName == domain && e.wildcard == wildcard) ||
          _payload.now.denied.any((e) => e.domainName == domain && e.wildcard == wildcard);
    }
    return _payload.now.allowed.any((e) => e.domainName == domain) ||
        _payload.now.denied.any((e) => e.domainName == domain);
  }

  /// Check if domain exists in allowed customlist
  /// Reusable method for checking allowed list entries
  bool isInAllowedList(String domain, {bool? wildcard}) {
    final allowed = _payload.now.allowed;
    if (wildcard != null) {
      // Check for specific wildcard value
      return allowed.any((e) => e.domainName == domain && e.wildcard == wildcard);
    }
    // Check if domain exists with any wildcard value
    return allowed.any((e) => e.domainName == domain);
  }

  /// Check if domain exists in denied/blocked customlist
  /// Reusable method for checking blocked list entries
  bool isInBlockedList(String domain, {bool? wildcard}) {
    final denied = _payload.now.denied;
    if (wildcard != null) {
      // Check for specific wildcard value
      return denied.any((e) => e.domainName == domain && e.wildcard == wildcard);
    }
    // Check if domain exists with any wildcard value
    return denied.any((e) => e.domainName == domain);
  }
}
