import 'package:common/src/core/core.dart';
import 'package:common/src/features/link/domain/link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("manageSubscriptions has a template per platform", () {
    final ios = linkTemplates.where(
        (t) => t.id == LinkId.manageSubscriptions && t.platform == PlatformType.iOS);
    final android = linkTemplates.where(
        (t) => t.id == LinkId.manageSubscriptions && t.platform == PlatformType.android);
    expect(ios.single.url, "https://apps.apple.com/account/subscriptions");
    expect(android.single.url,
        "https://play.google.com/store/account/subscriptions?package=org.blokada.sex");
  });
}
