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

/// Represents a customlist rule that is relevant to a given domain
/// Includes metadata about how the rule matches (exact or parent wildcard)
class RelevantCustomlistRule {
  final String domain;
  final JsonCustomListAction action;
  final bool wildcard;
  final String matchType; // 'exact' or 'parent'
  final int level; // 0 for exact, 1+ for parent levels up

  RelevantCustomlistRule({
    required this.domain,
    required this.action,
    required this.wildcard,
    required this.matchType,
    required this.level,
  });

  bool get isExact => matchType == 'exact';
  bool get isParent => matchType == 'parent';
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

  /// Get all customlist rules that are relevant for a given domain
  /// This includes exact matches and parent wildcard rules
  ///
  /// Example: for "ads.www.apple.com", this returns rules for:
  /// - "ads.www.apple.com" (exact, level 0)
  /// - "www.apple.com" (parent wildcard, level 1)
  /// - "apple.com" (parent wildcard, level 2)
  ///
  /// Rules are sorted by specificity: exact first, then by level (closer parents first)
  List<RelevantCustomlistRule> getRelevantRulesForDomain(String domain) {
    final rules = <RelevantCustomlistRule>[];

    // Check exact match (both wildcard=false and wildcard=true for exact domain)
    final exactAllowedNonWildcard = _payload.now.allowed
        .where((e) => e.domainName == domain && !e.wildcard);
    final exactBlockedNonWildcard = _payload.now.denied
        .where((e) => e.domainName == domain && !e.wildcard);

    final exactAllowedWildcard = _payload.now.allowed
        .where((e) => e.domainName == domain && e.wildcard);
    final exactBlockedWildcard = _payload.now.denied
        .where((e) => e.domainName == domain && e.wildcard);

    // Add non-wildcard exact matches
    for (var entry in exactAllowedNonWildcard) {
      rules.add(RelevantCustomlistRule(
        domain: entry.domainName,
        action: JsonCustomListAction.allow,
        wildcard: entry.wildcard,
        matchType: 'exact',
        level: 0,
      ));
    }

    for (var entry in exactBlockedNonWildcard) {
      rules.add(RelevantCustomlistRule(
        domain: entry.domainName,
        action: JsonCustomListAction.block,
        wildcard: entry.wildcard,
        matchType: 'exact',
        level: 0,
      ));
    }

    // Add wildcard exact matches
    for (var entry in exactAllowedWildcard) {
      rules.add(RelevantCustomlistRule(
        domain: entry.domainName,
        action: JsonCustomListAction.allow,
        wildcard: entry.wildcard,
        matchType: 'exact',
        level: 0,
      ));
    }

    for (var entry in exactBlockedWildcard) {
      rules.add(RelevantCustomlistRule(
        domain: entry.domainName,
        action: JsonCustomListAction.block,
        wildcard: entry.wildcard,
        matchType: 'exact',
        level: 0,
      ));
    }

    // Check parent domains (only wildcards apply to subdomains)
    final parts = domain.split('.');
    for (int i = 1; i < parts.length; i++) {
      final parentDomain = parts.sublist(i).join('.');

      // Only wildcard rules on parent domains affect subdomains
      final parentAllowedWildcard = _payload.now.allowed
          .where((e) => e.domainName == parentDomain && e.wildcard);
      final parentBlockedWildcard = _payload.now.denied
          .where((e) => e.domainName == parentDomain && e.wildcard);

      for (var entry in parentAllowedWildcard) {
        rules.add(RelevantCustomlistRule(
          domain: entry.domainName,
          action: JsonCustomListAction.allow,
          wildcard: entry.wildcard,
          matchType: 'parent',
          level: i,
        ));
      }

      for (var entry in parentBlockedWildcard) {
        rules.add(RelevantCustomlistRule(
          domain: entry.domainName,
          action: JsonCustomListAction.block,
          wildcard: entry.wildcard,
          matchType: 'parent',
          level: i,
        ));
      }
    }

    // Sort: parent wildcard first, then exact rules, ordered by level (closer parents first)
    rules.sort((a, b) {
      if (a.matchType == 'exact' && b.matchType != 'exact') return 1;
      if (a.matchType != 'exact' && b.matchType == 'exact') return -1;
      return a.level.compareTo(b.level);
    });

    return rules;
  }
}
