part of 'link.dart';

const _keyAcc = "account-id=ACCOUNTID";
const _keyUA = "USERAGENT";

final _linkTemplates = {
  // Primary links
  LinkTemplate(LinkId.support, null, null,
      "https://app.blokada.org/support?user-agent=$_keyUA&$_keyAcc"),
  LinkTemplate(LinkId.knowledgeBase, PlatformType.iOS, Flavor.v6,
      "https://go.blokada.org/kb_ios"),
  LinkTemplate(LinkId.knowledgeBase, PlatformType.iOS, Flavor.family,
      "https://go.blokada.org/kb_ios_family"),
  LinkTemplate(LinkId.knowledgeBase, PlatformType.android, null,
      "https://go.blokada.org/kb_android"),
  LinkTemplate(LinkId.tos, null, Flavor.v6, "https://go.blokada.org/terms"),
  LinkTemplate(
      LinkId.tos, null, Flavor.family, "https://go.blokada.org/terms_family"),
  LinkTemplate(
      LinkId.privacy, null, Flavor.v6, "https://go.blokada.org/privacy"),
  LinkTemplate(LinkId.privacy, null, Flavor.family,
      "https://go.blokada.org/privacy_family"),
  LinkTemplate(
      LinkId.privacyCloud, null, null, "https://go.blokada.org/privacy_cloud"),
  LinkTemplate(LinkId.manageSubscriptions, null, null,
      "https://apps.apple.com/account/subscriptions"),
  LinkTemplate(LinkId.credits, null, null, "https://blokada.org/"),
  // Less important (mostly legacy) links
  LinkTemplate(LinkId.whyVpn, null, null, "https://go.blokada.org/vpn"),
  LinkTemplate(LinkId.whatIsDns, null, null, "https://go.blokada.org/dns"),
  LinkTemplate(
      LinkId.whyVpnPermissions, null, null, "https://go.blokada.org/vpnperms"),
  LinkTemplate(LinkId.cloudDnsSetup, null, null,
      "https://go.blokada.org/cloudsetup_ios"),
  LinkTemplate(
      LinkId.howToRestore, null, null, "https://go.blokada.org/vpnrestore"),
};

class LinkActor with Logging, Actor {
  late final _channel = Core.get<LinkChannel>();
  late final _env = Core.get<EnvActor>();
  late final _isLocked = Core.get<IsLocked>();

  late final _account = Core.get<AccountStore>(); // TODO: change
  late final _linkedMode = Core.get<FamilyLinkedMode>(); // TODO: change

  String userAgent = "";
  Map<LinkId, LinkTemplate> templates = {};
  Map<LinkId, String> links = {};

  @override
  onStart(Marker m) async {
    await _prepareTemplates();
    _account.addOn(accountChanged, updateLinksFromAccount);
    if (Core.act.isFamily) {
      _linkedMode.onChange.listen(updateFromLinkedMode);
    }

    _isLocked.onChange.listen(updateLinksFromLock);

    userAgent = _env.userAgent;
  }

  updateLinksFromLock(ValueUpdate<bool> isLocked) async {
    return await log(Markers.root).trace("updateLinksFromLock", (m) async {
      log(m).pair("isLocked", isLocked.now);
      await _updateLinks();
    });
  }

  Future<void> updateLinksFromAccount(Marker m) async {
    return await log(m).trace("updateLinksFromAccount", (m) async {
      await _updateLinks();
    });
  }

  updateFromLinkedMode(ValueUpdate<bool> linked) => _updateLinks();

  _updateLinks() async {
    final linked = Core.act.isFamily && _linkedMode.now;
    for (var id in LinkId.values) {
      links[id] = _getLink(id, _isLocked.now || linked);
    }

    await _channel.doLinksChanged(links);
  }

  _prepareTemplates() async {
    final p = Core.act.platform;
    final f = Core.act.flavor;

    for (var id in LinkId.values) {
      try {
        // Find the correct link template
        LinkTemplate? template;
        var links = _linkTemplates.filter((e) => e.id == id);
        if (links.length > 1) {
          template =
              links.firstWhereOrNull((e) => e.platform == p && e.flavor == f);
          template ??=
              links.firstWhere((e) => e.platform == p || e.flavor == f);
        } else {
          template = links.first;
        }

        templates[id] = template;
      } catch (e) {
        throw Exception("Failed to prepare link template for $id: $e");
      }
    }
  }

  String _getLink(LinkId id, bool isLocked) {
    // Replace placeholders as applicable
    String link = templates[id]!.url;
    link = link.replaceFirst(_keyUA, userAgent);
    final accountId = _account.account?.id;

    if (isLocked || accountId == null) {
      return link.replaceFirst(_keyAcc, "");
    } else {
      return link.replaceFirst(_keyAcc, "account-id=$accountId");
    }
  }
}
