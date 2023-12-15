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

@HostApi()
abstract class LinkOps {
  @async
  void doLinksChanged(Map<LinkId, String> links);
}
