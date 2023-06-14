import 'dart:math';

import '../util/config.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'collectors.dart';

final _random = Random.secure();
String generateTraceId(int len) {
  final values = List<int>.generate(len, (i) => _random.nextInt(256));
  return values.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

// Common parent trace id for the whole app runtime
final runtimeTraceId = generateTraceId(16);
String? runtimeLastError;

class DefaultTracer with Tracer, Dependable {
  @override
  attach(Act act) {
    depend<Tracer>(this);
    depend<TracerOps>(getOps(act));
    depend<TraceCollector>(DefaultTraceCollectorManager());
  }

  @override
  newTrace(String module, String name, {bool? important}) {
    return DefaultTrace.as(generateTraceId(8), module, name,
        important: important);
  }
}

abstract class TraceCollector {
  onStart(DefaultTrace t);
  onEnd(DefaultTrace t);
  onEvent(DefaultTrace t, TraceEvent e);
}

class DefaultTraceCollectorManager with TraceCollector {
  final _file = FileTraceCollector();
  final _stdout =
      cfg.logToConsole ? StdoutTraceCollector() : NoopTraceCollector();
  final _api = cfg.debugSendTracesTo != null
      ? JsonTraceCollector(immediate: false, uri: cfg.debugSendTracesTo!)
      : null;

  @override
  onStart(DefaultTrace t) async {
    await _stdout.onStart(t);
    await _api?.onStart(t);
    await _file.onStart(t);
  }

  @override
  onEnd(DefaultTrace t) async {
    await _stdout.onEnd(t);
    await _api?.onEnd(t);
    await _file.onEnd(t);
  }

  @override
  onEvent(DefaultTrace t, TraceEvent e) async {
    await _stdout.onEvent(t, e);
  }
}
