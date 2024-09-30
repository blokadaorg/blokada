part of 'logger.dart';

// Will group together logs corresponding to one execution chain.
// Meant to improve log readability and debugging.
class LogTracer with Dependable {
  static final Map<Marker, TracingEvent> _traces = {};

  late final _logger = dep<Logger>();
  late final _timer = dep<TimerService>();

  final timeout = const Duration(seconds: 15);

  @override
  void attach(Act act) {
    depend<LogTracer>(this);
    if (act.isTest()) return;
    _onTimeout();
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

    _logger.log(current.level, current.lines.join("\n"));

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
    if (act.isTest()) return;
    _timer.set(_timeoutKey, DateTime.now().add(timeout));
  }

  _onTimeout() {
    _timer.addHandler(_timeoutKey, (_) async {
      for (var trace in _traces.entries.toList()) {
        if (trace.value.started.isBefore(DateTime.now().subtract(timeout))) {
          _logger.log(Level.error, trace.value.lines.join("\n"),
              error: Exception("Tracer: too slow: ${trace.value.lines.first}"));
          _traces.remove(trace.key);
        }
      }
    });
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
    // if (level <= 3) return "➰" * level + line;
    // return "➰" * (level - 1) + _indentToKeyCap(level) + line;
    // return _indentToKeyCap(level) * (level) + line;
  }

  // String _indentToKeyCap(int level) {
  //   if (level > 9) return "🔟";
  //   if (level == 9) return "9️⃣";
  //   if (level == 8) return "8️⃣";
  //   if (level == 7) return "7️⃣";
  //   if (level == 6) return "6️⃣";
  //   if (level == 5) return "5️⃣";
  //   return "4️⃣";
  // }

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
