import 'dart:io';

import 'package:common/tracer/collectors.dart';
import 'package:common/util/act.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:common/tracer/tracer.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:test_api/src/backend/invoker.dart';
import 'package:flutter_test/flutter_test.dart';

final _tracer = dep<TraceFactory>();

withTrace(Future Function(Trace trace) fn) async {
  await dep.reset();
  depend<TraceFactory>(Tracer());
  depend<TraceCollector>(StdoutTraceCollector());

  final m = (goldenFileComparator as LocalFileComparator).basedir.pathSegments;
  final module = m[m.length - 2];
  final group = Invoker.current!.liveTest.groups.last.name;
  final test = Invoker.current!.liveTest.individualName.capitalize;
  final trace = _tracer.newTrace("test:$module", "$group:$test");
  await fn(trace);
  await trace.end();
}

mockAct(Dependable subject,
    {Flavor flavor = Flavor.og, Platform platform = Platform.ios}) {
  final act = ActScreenplay(ActScenario.platformIsMocked, flavor, platform);
  subject.setActForTest(act);
  return act;
}

final mockedAct =
    ActScreenplay(ActScenario.platformIsMocked, Flavor.og, Platform.ios);
