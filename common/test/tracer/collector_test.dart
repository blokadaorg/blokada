import 'dart:convert';

import 'package:common/tracer/channel.pg.dart';
import 'package:common/tracer/collectors.dart';
import 'package:common/tracer/tracer.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<TracerOps>(),
])
import 'collector_test.mocks.dart';

void main() {
  group("fileTraceCollector", () {
    test("basicTest", () async {
      // Outside of the tracing because we need to hook into it
      await dep.reset();

      final tracer = DefaultTracer();
      depend<Tracer>(tracer);

      var output = "";
      final ops = MockTracerOps();
      when(ops.doStartFile(any)).thenAnswer((i) async {
        output = i.positionalArguments[0];
      });
      when(ops.doSaveBatch(any, any)).thenAnswer((i) async {
        final data = i.positionalArguments[0] as String;
        final mark = i.positionalArguments[1] as String;
        final pos = output.lastIndexOf(mark);
        final afterPos = output.substring(pos);
        output = output.substring(0, pos) + data + afterPos;
      });
      depend<TracerOps>(ops);

      final subject = FileTraceCollector();
      depend<TraceCollector>(subject);

      final parent = tracer.newTrace("testModule1", "root");
      final child1 = parent.start("testModule1", "child1");
      await child1.addAttribute("child1 attribute", "child1 value");

      final child2 = parent.start("testModule1", "child2");
      await child2.addEvent("child2 event");

      final child2child = child2.start("testModule2", "child2child");

      child2child.endWithFailure(Exception("test"), StackTrace.current);
      await child2.end();
      await child1.end();
      await parent.end();

      // Is timer based right now

      // print(output);
      //
      // // Will throw if not valid json
      // final decoded = jsonDecode(output);
      //
      // verify(ops.doStartFile(any)).called(1);
      // verify(ops.doSaveBatch(any, any)).called(4);
    });
  });
}
