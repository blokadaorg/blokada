import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:test_api/src/backend/invoker.dart';

String getTestName() {
  return "test:${Invoker.current!.liveTest.groups.last.name}:test${Invoker.current!.liveTest.individualName.capitalize}";
}

withTrace(Future Function(Trace trace) fn) async {
  final trace = DebugTrace.as(getTestName());
  await di.reset();
  await fn(trace);
  trace.end();
}
