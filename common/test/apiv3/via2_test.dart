import 'package:common/dragon/tracer.dart';
import 'package:common/tracer/collectors.dart';
import 'package:common/tracer/tracer.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("Via2", () {
    test("basic", () async {
      depend<TraceCollector>(StdoutTraceCollector());
      await Parent().run();
    });
  });
}

class Parent {
  run() async {
    final trace = tracer.start("parent", "run");
    await Child().hello();
    tracer.end(trace);
  }
}

class Child {
  hello() async {
    final trace = tracer.start("child", "hello");
    await Future.delayed(Duration(seconds: 1), () => print("hello"));
    tracer.end(trace);
  }
}
