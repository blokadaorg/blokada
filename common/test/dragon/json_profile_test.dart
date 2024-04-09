import 'package:common/common/model.dart';
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
