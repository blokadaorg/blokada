import 'package:common/src/core/core.dart';
import 'package:common/src/features/link/domain/link.dart';
import 'package:flutter_test/flutter_test.dart';

Iterable<LinkTemplate> _for(LinkId id) => linkTemplates.where((t) => t.id == id);

String _select(LinkId id, PlatformType platform, Flavor flavor) =>
    selectLinkTemplate(_for(id), platform, flavor).url;

void main() {
  test("manageSubscriptions has a template per platform", () {
    final ios = _for(LinkId.manageSubscriptions)
        .where((t) => t.platform == PlatformType.iOS);
    final android = _for(LinkId.manageSubscriptions)
        .where((t) => t.platform == PlatformType.android);
    expect(ios.single.url, "https://apps.apple.com/account/subscriptions");
    expect(
        android.firstWhere((t) => t.flavor == Flavor.v6).url,
        "https://play.google.com/store/account/subscriptions?package=org.blokada.sex");
    expect(
        android.firstWhere((t) => t.flavor == Flavor.family).url,
        "https://play.google.com/store/account/subscriptions?package=org.blokada.family");
  });

  group("selectLinkTemplate", () {
    test("resolves manageSubscriptions by platform", () {
      expect(_select(LinkId.manageSubscriptions, PlatformType.iOS, Flavor.v6),
          "https://apps.apple.com/account/subscriptions");
      expect(_select(LinkId.manageSubscriptions, PlatformType.android, Flavor.v6),
          "https://play.google.com/store/account/subscriptions?package=org.blokada.sex");
      expect(_select(LinkId.manageSubscriptions, PlatformType.android, Flavor.family),
          "https://play.google.com/store/account/subscriptions?package=org.blokada.family");
    });

    test("falls back to the unscoped catch-all on an unnamed platform", () {
      expect(
          _select(LinkId.manageSubscriptions, PlatformType.unknown, Flavor.v6),
          "https://apps.apple.com/account/subscriptions");
    });

    test("still resolves knowledgeBase by platform and flavor", () {
      expect(_select(LinkId.knowledgeBase, PlatformType.iOS, Flavor.family),
          "https://go.blokada.org/kb_ios_family");
      expect(_select(LinkId.knowledgeBase, PlatformType.iOS, Flavor.v6),
          "https://go.blokada.org/kb_ios");
    });

    test("never picks another platform's template on a flavor match", () {
      // Regression for the platform-vs-flavor precedence bug (issue-tracker#341):
      // the android entry has no flavor, and the flavored iOS entries must not
      // win just because their flavor matches.
      expect(_select(LinkId.knowledgeBase, PlatformType.android, Flavor.v6),
          "https://go.blokada.org/kb_android");
      expect(_select(LinkId.knowledgeBase, PlatformType.android, Flavor.family),
          "https://go.blokada.org/kb_android");
    });

    test("flavor-only templates resolve on any platform", () {
      expect(_select(LinkId.tos, PlatformType.android, Flavor.family),
          "https://go.blokada.org/terms_family");
    });

    test("every link id resolves on every platform and flavor", () {
      for (final id in LinkId.values) {
        for (final platform in PlatformType.values) {
          for (final flavor in Flavor.values) {
            expect(() => _select(id, platform, flavor), returnsNormally,
                reason: "$id on $platform/$flavor");
          }
        }
      }
    });
  });
}
