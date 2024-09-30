import 'package:common/util/cooldown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tools.dart';

void main() {
  group("cooldown", () {
    test("basicTest", () async {
      await withTrace((m) async {
        final subject = _Subject();

        // Will track the cooldown wait time
        expect(subject.isCooledDown(const Duration(seconds: 1)), true);
        expect(subject.isCooledDown(const Duration(seconds: 1)), false);

        expect(subject.isCooledDown(const Duration(seconds: 0)), true);
      });
    });
  });
}

class _Subject with Cooldown {}
