import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("json_profile", () {
    test("displayAlias", () async {
      final subject = JsonProfile(
        profileId: "1",
        alias: "Bobby (child)",
        lists: [],
        safeSearch: false,
      );

      expect("child", subject.template);
      expect("Bobby", subject.displayAlias);
    });
  });
}
