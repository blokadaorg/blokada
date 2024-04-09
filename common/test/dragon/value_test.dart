import 'package:common/dragon/value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("NullableValue", () {
    test("basic", () async {
      final subject = TestValue(onLoad: () => "ok");
      await subject.fetch();
      expect(subject.now, "ok");
    });

    test("failing", () async {
      final subject = TestValue(onLoad: () => throw Exception("fail"));
      try {
        await subject.fetch();
      } catch (e) {
        print("Caught $e");
      }
      expect(subject.now, "ok");
    });
  });
}

class TestValue extends NullableValue<String> {
  final String Function() onLoad;

  TestValue({required this.onLoad});

  @override
  Future<String?> doLoad() async {
    return onLoad();
  }
}
