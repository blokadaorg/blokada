part of 'link.dart';

enum LinkId {
  // Primary links
  support,
  knowledgeBase,
  tos,
  privacy,
  privacyCloud,
  manageSubscriptions,
  // Settings "Your plan" routes by where the plan was bought, which can differ
  // from the platform the app runs on (bought on iPhone, now on Android).
  manageSubscriptionsAppStore,
  manageSubscriptionsPlayStore,
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
