import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../tools.dart';

void main() {
  group("Field", () {
    test("basic", () async {
      await withTrace((trace) async {});
    });
  });

  group("inheritance", () {
    test("basic", () async {
      await withTrace((trace) async {
        final subject = _TwoTest();
        expect(await subject.a(), "b1");
      });
    });
  });
}

class _OneTest with _Test {
  @override
  Future<String> a() async => b();
  @override
  Future<String> b() async => "b1";
}

class _TwoTest extends _OneTest {
  @override
  Future<String> a() async {
    print("two a");
    return super.a();
  }

  @override
  Future<String> b() async {
    print("two b");
    return super.b();
  }
}

mixin _Test {
  Future<String> a() async => "a";
  Future<String> b() async => "b";
}
