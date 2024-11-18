part of '../core.dart';

// Will group together logs corresponding to one execution chain.
// Meant to improve log readability and debugging.
class LogTracer with Actor {
  static final Map<Marker, TracingEvent> _traces = {};

  late final _logger = DI.get<Logger>();
  late final _scheduler = DI.get<Scheduler>();

  final timeout = const Duration(seconds: 15);

  @override
  void onRegister(Act act) {
    DI.register<LogTracer>(this);
    if (act.isTest) return;
  }

  sink(Marker m, Level lvl, List<String> lines,
      {Object? err, StackTrace? stack}) {
    final current = _traces[m];
    if (current == null) {
      final l = ["Marker.${Markers.toName(m)}"];
      l.addAll(lines);
      _logger.log(lvl, l.join("\n"));
      return;
    }

    current.addLines(lines);
    current.promoteLevel(lvl);
    current.error = err ?? current.error;
    current.stackTrace = stack ?? current.stackTrace;
  }

  begin(Marker m, String line) {
    TracingEvent? current = _traces[m];
    if (current == null) {
      current = TracingEvent();
      _traces[m] = current;
      current.addLine("Marker.${Markers.toName(m)}");
      _startTimeout();
    }

    current.addLine(line);
    current.nested++;
  }

  end(Marker m, Level lvl, String name, String line) {
    final current = _traces[m];
    if (current == null) {
      _logger.e("Marker.${Markers.toName(m)}\n$name",
          error: Exception("Tracer: end without begin"));
      return;
    }

    current.nested--;
    if (current.nested > 0) {
      current.addLine(line, mergeBy: name);
      return;
    }

    current.addLine(line, mergeBy: name);
    current.promoteLevel(lvl);

    if (current.error == null) {
      _logger.log(current.level, current.lines.join("\n"));
    } else {
      _logger.log(current.level, current.lines.join("\n"),
          error: current.error, stackTrace: current.stackTrace);
    }

    _traces.remove(m);
  }

  endFail(Marker m, String line, Object error, StackTrace stackTrace) {
    final current = _traces[m];
    if (current == null) {
      _logger.e("Marker.${Markers.toName(m)}\n$line",
          error: Exception("Tracer: end without begin"));
      _logger.e("Marker.${Markers.toName(m)}\nActual error",
          error: error, stackTrace: stackTrace);
      return;
    }

    current.nested--;
    if (current.nested > 0) {
      current.addLine(line);
      return;
    }

    current.addLine(line);
    current.error = error;
    current.stackTrace = stackTrace;
    current.promoteLevel(Level.error);

    _logger.log(current.level, current.lines.join("\n"),
        error: current.error, stackTrace: current.stackTrace);

    _traces.remove(m);
  }

  _startTimeout() {
    if (act.isTest) return;
    if (kReleaseMode) return;
    _scheduler.addOrUpdate(Job(
      _timeoutKey,
      Markers.timer,
      before: DateTime.now().add(timeout),
      callback: _hangTraceCheck,
    ));
  }

  Future<bool> _hangTraceCheck(Marker m) async {
    for (var trace in _traces.entries.toList()) {
      if (trace.value.started.isBefore(DateTime.now().subtract(timeout))) {
        sink(trace.key, Level.error, ["Tracer: too slow"]);
        _logger.log(Level.error, trace.value.lines.join("\n"),
            error: Exception(
                "Tracer: too slow: ${trace.value.lines.skip(1).first}"));

        // Let the trace continue as maybe it will finish
        // Otherwise we end up with "end without begin" error (above)
        // But we also mark the existing trace using sink (above)
        // Since it may merge with a future trace of same marker
        //_traces.remove(trace.key);
      }
    }
    return false;
  }
}

class TracingEvent {
  final List<String> lines = [];
  Level level = Level.trace;
  Object? error;
  StackTrace? stackTrace;
  int nested = 0;
  DateTime started = DateTime.now();

  addLine(String line, {String? mergeBy}) {
    if (mergeBy != null) {
      final last = lines.isEmpty ? "" : lines.last;
      if (last.contains(mergeBy)) {
        lines.removeLast();
        lines.add(_prefixIndent(nested, "⏩ $line"));
        return;
      }
    }
    lines.add(_prefixIndent(nested, line));
  }

  addLines(List<String> lines) {
    for (var line in lines) {
      addLine(line);
    }
  }

  String _prefixIndent(int level, String line) {
    if (level < 3) return "➰" * level + line;
    return "${"➰" * level} [$level] $line";
  }

  promoteLevel(Level lvl) {
    if (lvl == Level.error) {
      level = Level.error;
    } else if (lvl == Level.warning && level != Level.error) {
      level = Level.warning;
    } else if (lvl == Level.info &&
        level != Level.error &&
        level != Level.warning) {
      level = Level.info;
    }
  }
}

const _timeoutKey = "LogTracer:HangTraceCheck";
