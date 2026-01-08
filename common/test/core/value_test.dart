import 'package:common/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tools.dart';

void main() {
  group("NullableAsyncValue", () {
    test("basic", () async {
      await withTrace((m) async {
        final subject = TestValue(onLoad: (m) async => "ok");
        await subject.fetch(Markers.testing);
        expect(await subject.now(), "ok");
      });
    });

    // test("failing", () async {
    //   final subject = TestValue(onLoad: () => throw Exception("fail"));
    //   try {
    //     await subject.fetch();
    //   } catch (e) {
    //     print("Caught $e");
    //   }
    //   expect(subject.now, "ok");
    // });
  });
}

class TestValue extends NullableAsyncValue<String> {
  final Future<String> Function(Marker m) onLoad;

  TestValue({required this.onLoad}) {
    load = onLoad;
  }
}
