import 'package:pigeon/pigeon.dart';

enum LinkId {
  // Primary links
  support,
  knowledgeBase,
  tos,
  privacy,
  privacyCloud,
  manageSubscriptions,
  credits,

  // Less important (mostly legacy) links
  whyVpn,
  whatIsDns,
  whyVpnPermissions,
  cloudDnsSetup,
  howToRestore,
}

class Link {
  LinkId id;
  String url;

  Link(this.id, this.url);
}

@HostApi()
abstract class LinkOps {
  @async
  void doLinksChanged(List<Link> links);
}
