part of 'link.dart';

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

class LinkTemplate {
  final LinkId id;
  final PlatformType? platform;
  final Flavor? flavor;
  final String url;

  LinkTemplate(this.id, this.platform, this.flavor, this.url);
}
