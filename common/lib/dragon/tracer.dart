import 'dart:math';

import '../tracer/collectors.dart';
import '../util/trace.dart';

final tracer = Tracer();

class Tracer {
  List<Trace> current = [];

  Trace start(String module, String name) {
    print("Starting trace $module/$name");
    final c = current.lastOrNull;

    Trace t;
    if (c != null) {
      t = c.start(module, name);
    } else {
      t = _newTrace(module, name);
    }
    current.add(t);

    return t;
  }

  end(Trace trace, {Error? e, StackTrace? s}) {
    print("Ending trace $trace");
    if (trace == current.lastOrNull) {
      if (e != null) {
        trace.endWithFatal(e, s!);
      } else {
        trace.end();
      }
      current.removeLast();
    } else {
      throw StateError("Trying to end a trace that is not the current one. "
          "Current: ${current.lastOrNull}, ending: $trace");
    }
  }

  _newTrace(String module, String name, {bool? important}) {
    return DefaultTrace.as(generateTraceId(8), module, name,
        important: important);
  }
}

final _random = Random.secure();
String generateTraceId(int len) {
  final values = List<int>.generate(len, (i) => _random.nextInt(256));
  return values.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
