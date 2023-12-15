import 'package:collection/collection.dart';
import 'package:dartx/dartx.dart';
import 'package:mobx/mobx.dart';

import 'channel.act.dart';
import '../account/account.dart';
import '../env/env.dart';
import '../lock/lock.dart';
import '../util/act.dart';
import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.pg.dart';

part 'link.g.dart';

class LinkStore = LinkStoreBase with _$LinkStore;

class LinkTemplate {
  final LinkId id;
  final Platform? platform;
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
  LinkTemplate(LinkId.knowledgeBase, Platform.ios, Flavor.og,
      "https://go.blokada.org/kb_ios"),
  LinkTemplate(LinkId.knowledgeBase, Platform.ios, Flavor.family,
      "https://go.blokada.org/kb_ios_family"),
  LinkTemplate(LinkId.knowledgeBase, Platform.android, null,
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

abstract class LinkStoreBase with Store, Traceable, Dependable, Startable {
  late final _ops = dep<LinkOps>();
  late final _env = dep<EnvStore>();
  late final _account = dep<AccountStore>();
  late final _lock = dep<LockStore>();

  String userAgent = "";
  Map<LinkId, LinkTemplate> templates = {};
  Map<LinkId, String> links = {};

  @override
  attach(Act act) {
    depend<LinkOps>(getOps(act));
    depend<LinkStore>(this as LinkStore);
    _lock.addOnValue(lockChanged, updateLinks);
  }

  @override
  @action
  Future<void> start(Trace parentTrace) async {
    return await traceWith(parentTrace, "startLink", (trace) async {
      await _prepareTemplates(trace);
      userAgent = _env.userAgent!;
    });
  }

  @action
  Future<void> updateLinks(Trace parentTrace, bool isLocked) async {
    return await traceWith(parentTrace, "updateLinks", (trace) async {
      for (var id in LinkId.values) {
        links[id] = _getLink(id, isLocked);
      }

      List<Link> converted =
          links.entries.map((e) => Link(id: e.key, url: e.value)).toList();

      await _ops.doLinksChanged(converted);
    });
  }

  _prepareTemplates(Trace trace) async {
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
    link = link.replaceFirst(_keyUA, userAgent.urlEncode);

    if (isLocked) {
      return link.replaceFirst(_keyAcc, "");
    } else {
      return link.replaceFirst(_keyAcc, "account-id=${_account.id}");
    }
  }
}
