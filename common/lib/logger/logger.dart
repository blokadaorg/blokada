import 'dart:developer' as developer;

import 'package:common/logger/channel.pg.dart';
import 'package:common/util/di.dart';
import 'package:common/util/platform_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../timer/timer.dart';
import 'channel.act.dart';

part 'marker.dart';
part 'output.dart';
part 'trace.dart';

class Log {
  late final LogTracer _tracer = dep<LogTracer>();

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
      _tracer.sink(marker, Level.error, ["$tag: $msg"], err: err, stack: stack);

  pair(String key, dynamic value) => log(attr: {key: value});
  params(Map<String, dynamic> attr) => log(attr: attr);

  log({
    String? msg,
    Map<String, dynamic>? attr,
    Level lvl = Level.info,
    bool sensitive = false,
  }) {
    var lines = <String>[];
    if (msg != null) {
      lines.add("💡 $tag 📝 $msg");
    }

    if (attr != null) {
      for (var key in attr.keys) {
        if (sensitive && kReleaseMode) {
          var value = "*****";
          if (key == "url") {
            value = "${attr[key].toString().split("?")[0]}?*****";
          }

          lines.add("💡 $tag 🔍 $key = $value");
        } else {
          lines.add("💡 $tag 🔍 $key = ${attr[key]}");
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

class LoggerCommands with Logging, Dependable {
  late final _ops = dep<LoggerOps>();

  @override
  void attach(Act act) {
    depend<LoggerOps>(getOps(act));
    depend<Logger>(Logger(
      filter: ProductionFilter(),
      printer: _printer,
      output: FileLoggerOutput(act),
    ));
    LogTracer().attachAndSaveAct(act);
    depend<LoggerCommands>(this);
  }

  platformWarning(String msg) {
    log(Markers.platform).w(msg);
  }

  platformFatal(String msg) {
    log(Markers.platform).e(msg: "FATAL: $msg");
  }

  shareLog({bool forCrash = false}) {
    _ops.doShareFile();
  }

  // TODO: crash log stuff
}
