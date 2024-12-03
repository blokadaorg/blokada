part of 'customlist.dart';

class CustomlistPayload {
  final List<String> denied;
  final List<String> allowed;

  CustomlistPayload({required this.denied, required this.allowed});
}

class CustomlistActor with Actor, Logging {
  late final _customlist = Core.get<CustomlistApi>();
  late final _payload = Core.get<CustomlistPayloadValue>();

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
    final denied = entries
        .where((e) => e.action == JsonCustomListAction.block)
        .map((e) => e.domainName)
        .toList();
    denied.sort();

    final allowed = entries
        .where((e) => e.action == JsonCustomListAction.allow)
        .map((e) => e.domainName)
        .toList();
    allowed.sort();

    _payload.now = CustomlistPayload(denied: denied, allowed: allowed);
  }

  _allow(String domain, Marker m) async {
    _payload.now = CustomlistPayload(
      denied: _payload.now.denied,
      allowed: _payload.now.allowed..add(domain),
    );

    await _customlist.add(
        m,
        JsonCustomList(
          domainName: domain,
          action: JsonCustomListAction.allow,
          wildcard: false, // Ignored
        ),
        profileId: profileId);
  }

  _deny(String domain, Marker m) async {
    _payload.now = CustomlistPayload(
      denied: _payload.now.denied..add(domain),
      allowed: _payload.now.allowed,
    );

    await _customlist.add(
      m,
      JsonCustomList(
        domainName: domain,
        action: JsonCustomListAction.block,
        wildcard: false, // Ignored
      ),
      profileId: profileId,
    );
  }

  _delete(String domain, Marker m) async {
    _payload.now = CustomlistPayload(
      denied: _payload.now.denied..remove(domain),
      allowed: _payload.now.allowed..remove(domain),
    );

    await _customlist.delete(
      m,
      JsonCustomList(
        domainName: domain,
        action: JsonCustomListAction.allow, // Ignored
        wildcard: false, // Ignored
      ),
      profileId: profileId,
    );
  }

  addOrRemove(String domain, Marker m, {required bool gotBlocked}) async {
    if (contains(domain)) {
      await _delete(domain, m);
    } else if (gotBlocked) {
      await _allow(domain, m);
    } else {
      await _deny(domain, m);
    }
    await fetch(m);
  }

  bool contains(String domain) {
    // todo: wildcard?
    return _payload.now.allowed.contains(domain) ||
        _payload.now.denied.contains(domain);
  }
}
