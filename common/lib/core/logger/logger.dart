part of '../core.dart';

class Log {
  late final LogTracerActor _tracer = Core.get<LogTracerActor>();

  late Marker marker;
  late String tag = "$runtimeType";

  t(String msg) => log(msg: msg, lvl: Level.trace);

  i(String msg) => log(msg: msg);

  w(String msg) => log(msg: msg, lvl: Level.warning);

  e({
    String? msg,
    Object? err,
    StackTrace? stack,
  }) =>
      _tracer.sink(marker, Level.error, ["⛔ $tag: $msg"],
          err: err, stack: stack);

  pair(String key, dynamic value) => log(attr: {key: value});
  params(Map<String, dynamic> attr) => log(attr: attr);

  logt({
    String? msg,
    Map<String, dynamic>? attr,
    bool sensitive = false,
  }) =>
      log(msg: msg, attr: attr, lvl: Level.trace, sensitive: sensitive);

  log({
    String? msg,
    Map<String, dynamic>? attr,
    Level lvl = Level.info,
    bool sensitive = false,
  }) {
    var lines = <String>[];
    if (msg != null) {
      lines.add("➰ $tag 📝 $msg");
    }

    if (attr != null) {
      for (var key in attr.keys) {
        var value = attr[key];

        if (value != null &&
            !value.toString().isBlank &&
            sensitive &&
            Core.config.obfuscateSensitiveParams) {
          var param = value.toString();
          var censored = param;

          // For urls, we censor the sensitive params
          if (key == "url" && param.contains("?")) {
            final url = param.split("?");
            param = url[0];
            censored = url[1];
          }

          // Use hash so we can see if the param has changed, but not inclued it
          var bytes = utf8.encode(censored);
          var digest = md5.convert(bytes);

          value = "🔑 ${digest.toString()}";
          if (param != censored) {
            value = "$param? 🔑 $digest";
          }

          lines.add("➰ $tag 🔍 $key = $value");
        } else {
          if (value == null) {
            value = "(null)";
          } else if (value is String) {
            if (value.isEmpty) value = "(empty)";
            if (value.isBlank) value = "(blank)";
          }

          lines.add("➰ $tag 🔍 $key = $value");
        }
      }
    }

    _tracer.sink(marker, lvl, lines);
  }

  Future<T> trace<T>(
    String name,
    Future<T> Function(Marker) fn,
  ) async {
    final traceName = "$tag::$name";
    _tracer.begin(marker, "⏩ $traceName");

    final start = DateTime.now().millisecondsSinceEpoch;
    try {
      final result = await fn(marker);
      final end = DateTime.now().millisecondsSinceEpoch;
      final took = end - start;

      if (took > 3000) {
        _tracer.end(marker, Level.warning, traceName,
            "⏸️️ 🐌 🐌 $traceName (${took}ms)");
      } else if (took > 1000) {
        _tracer.end(
            marker, Level.warning, traceName, "⏸️️ 🐌 $traceName (${took}ms)");
      } else {
        _tracer.end(
            marker, Level.trace, traceName, "⏸️ $traceName (${took}ms)");
      }

      //   // Compact messages when normal operation
      //   if (out.lines[out.lines.length - 2].contains("$tag::$name")) {
      //     out.lines.removeAt(out.lines.length - 2);
      //     out.lines.last = "⏩ ${out.lines.last}";
      //   }
      // }

      return result;
    } catch (ex, s) {
      _tracer.endFail(marker, "⛔ $tag::$name ERROR", ex, s);
      rethrow;
    }
  }
}

mixin Logging {
  late final Log _log = Log();

  Log log(Marker m) {
    // This is not the best since its instance lifetime, the marker can be
    // overwritten. But, we return a new instance below for tracing.
    // For log methods, we can ignore this.
    _log.tag = "$runtimeType";
    _log.marker = m;

    final log = Log();
    log.tag = "$runtimeType";
    log.marker = m;
    return log;
  }

  String mapError(Object? e) {
    if (e == null) return "[no error object]";
    if (e is PlatformException) {
      final type = e.code;
      final msg = e.message ?? "";
      return "PlatformException($type; $msg)";
    } else {
      final s = e.toString();
      if (s.contains("instanceFactory != null")) {
        final type = s.split(" type ")[1].split(" is not registered ")[0];
        return "Missing dependency for $type";
      } else {
        return s;
      }
    }
  }
}
