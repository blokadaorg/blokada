import 'package:flutter_test/flutter_test.dart';

void main() {
  group("mixins", () {
    test("mixinsOrder", () {
      final subject = Final();
      expect(2, subject.doSomething());
    });
  });
}

class Final extends Original with Mixin1, Mixin2 {}

abstract class Original {
  int doSomething();
}

mixin Mixin1 on Original {
  @override
  int doSomething() {
    return 1;
  }
}

mixin Mixin2 on Original {
  @override
  int doSomething() {
    return 2;
  }
}
