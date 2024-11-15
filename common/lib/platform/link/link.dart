import 'package:collection/collection.dart';
import 'package:common/core/core.dart';
import 'package:common/dragon/family/family.dart';
import 'package:dartx/dartx.dart';
import 'package:mobx/mobx.dart';

import '../../lock/lock.dart';
import '../../util/mobx.dart';
import '../account/account.dart';
import '../env/env.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'link.g.dart';

class LinkStore = LinkStoreBase with _$LinkStore;

class LinkTemplate {
  final LinkId id;
  final PlatformType? platform;
  final Flavor? flavor;
  final String url;

  LinkTemplate(this.id, this.platform, this.flavor, this.url);
}

const _keyAcc = "account-id=ACCOUNTID";
const _keyUA = "USERAGENT";

final _linkTemplates = {
  // Primary links
  LinkTemplate(LinkId.support, null, null,
      "https://app.blokada.org/support?user-agent=$_keyUA&$_keyAcc"),
  LinkTemplate(LinkId.knowledgeBase, PlatformType.iOS, Flavor.og,
      "https://go.blokada.org/kb_ios"),
  LinkTemplate(LinkId.knowledgeBase, PlatformType.iOS, Flavor.family,
      "https://go.blokada.org/kb_ios_family"),
  LinkTemplate(LinkId.knowledgeBase, PlatformType.android, null,
      "https://go.blokada.org/kb_android"),
  LinkTemplate(LinkId.tos, null, Flavor.og, "https://go.blokada.org/terms"),
  LinkTemplate(
      LinkId.tos, null, Flavor.family, "https://go.blokada.org/terms_family"),
  LinkTemplate(
      LinkId.privacy, null, Flavor.og, "https://go.blokada.org/privacy"),
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

abstract class LinkStoreBase with Store, Logging, Dependable, Startable {
  late final _ops = dep<LinkOps>();
  late final _env = dep<EnvStore>();
  late final _account = dep<AccountStore>();
  late final _lock = dep<LockStore>();
  late final _family = dep<FamilyStore>();

  String userAgent = "";
  Map<LinkId, LinkTemplate> templates = {};
  Map<LinkId, String> links = {};

  @override
  attach(Act act) {
    depend<LinkOps>(getOps(act));
    depend<LinkStore>(this as LinkStore);
    _lock.addOnValue(lockChanged, updateLinksFromLock);
    _account.addOn(accountChanged, updateLinksFromAccount);
    if (act.isFamily()) {
      reactionOnStore((_) => _family.linkedMode, updateFromLinkedMode);
    }
  }

  @override
  @action
  Future<void> start(Marker m) async {
    return await log(m).trace("startLink", (m) async {
      await _prepareTemplates();
      userAgent = _env.userAgent!;
      //if (!userAgent.contains("%20")) userAgent = userAgent.urlEncode;
    });
  }

  @action
  Future<void> updateLinksFromLock(bool isLocked, Marker m) async {
    return await log(m).trace("updateLinksFromLock", (m) async {
      log(m).pair("isLocked", isLocked);
      await _updateLinks();
    });
  }

  @action
  Future<void> updateLinksFromAccount(Marker m) async {
    return await log(m).trace("updateLinksFromAccount", (m) async {
      await _updateLinks();
    });
  }

  updateFromLinkedMode(bool linked) => _updateLinks();

  _updateLinks() async {
    final linked = act.isFamily() && _family.linkedMode;
    for (var id in LinkId.values) {
      links[id] = _getLink(id, _lock.isLocked || linked);
    }

    List<Link> converted =
        links.entries.map((e) => Link(id: e.key, url: e.value)).toList();

    await _ops.doLinksChanged(converted);
  }

  _prepareTemplates() async {
    final p = act.getPlatform();
    final f = act.getFlavor();

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
