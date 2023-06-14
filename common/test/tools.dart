import 'dart:io';

import 'package:common/tracer/collectors.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:common/tracer/tracer.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:test_api/src/backend/invoker.dart';
import 'package:flutter_test/flutter_test.dart';

final _tracer = dep<Tracer>();

withTrace(Future Function(Trace trace) fn) async {
  await dep.reset();
  depend<Tracer>(DefaultTracer());
  depend<TraceCollector>(StdoutTraceCollector());

  final m = (goldenFileComparator as LocalFileComparator).basedir.pathSegments;
  final module = m[m.length - 2];
  final group = Invoker.current!.liveTest.groups.last.name;
  final test = Invoker.current!.liveTest.individualName.capitalize;
  final trace = _tracer.newTrace("test:$module", "$group:$test");
  await fn(trace);
  await trace.end();
}
