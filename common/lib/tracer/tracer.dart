import 'dart:math';

import '../persistence/persistence.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/config.dart';
import '../util/di.dart';
import '../util/platform_info.dart';
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

class Tracer with Dependable, Traceable implements TraceFactory {
  late final _crashCollector =
      FileTraceCollector(getLogFilename(forCrash: true), immediate: true);
  late final _stage = dep<StageStore>();
  late final _ops = dep<TracerOps>();
  late final _persistence = dep<PersistenceService>();

  @override
  attach(Act act) {
    depend<Tracer>(this);
    depend<TraceFactory>(this);
    depend<TracerOps>(getOps(act));
    depend<TraceCollector>(DefaultTraceCollectorManager());
  }

  @override
  newTrace(String module, String name, {bool? important}) {
    return DefaultTrace.as(generateTraceId(8), module, name,
        important: important);
  }

  // Propose the user to send the crash log if it exists from the previous run
  checkForCrashLog(Trace parentTrace) async {
    if (!await _ops.doFileExists(getLogFilename(forCrash: true))) return;

    return await traceWith(parentTrace, "proposeCrashLog", (trace) async {
      if (await _persistence.load(trace, "tracer:crashProposed") != null) {
        await deleteCrashLog(trace);
        await _persistence.delete(trace, "tracer:crashProposed");
      } else {
        await _stage.setRoute(trace, StageKnownRoute.homeOverlayCrash.path);
        await _persistence.saveString(trace, "tracer:crashProposed", "1");
      }
    });
  }

  deleteCrashLog(Trace parentTrace) async {
    return await traceWith(parentTrace, "deleteCrashLog", (trace) async {
      //await _stage.showModal(trace, StageModal.debugSharing);
      await _ops.doDeleteFile(getLogFilename(forCrash: true));
    });
  }

  shareLog(Trace parentTrace, {required bool forCrash}) async {
    return await traceWith(parentTrace, "shareCrashLog", (trace) async {
      await _ops.doShareFile(getLogFilename(forCrash: forCrash));
    });
  }

  platformWarning(Trace parentTrace, String error) async {
    return await traceWith(parentTrace, "platformWarning", (trace) async {
      // Platform code may call this method to report any error
      // This will report in tracing as error so we can easily see it
      throw Exception(error);
    });
  }

  fatal(String error) async {
    final trace = newTrace(runtimeType.toString(), "fatal");
    await _crashCollector.onStart(trace);
    await trace.endWithFatal(StateError(error), StackTrace.current);
    await _crashCollector.onEnd(trace);
  }
}

abstract class TraceCollector {
  onStart(DefaultTrace t);
  onEnd(DefaultTrace t);
  onEvent(DefaultTrace t, TraceEvent e);
}

class DefaultTraceCollectorManager implements TraceCollector {
  late final _file = FileTraceCollector(getLogFilename());
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

String getLogFilename({bool forCrash = false}) {
  final type = PlatformInfo().getCurrentPlatformType();
  final platform = type == PlatformType.iOS
      ? "i"
      : (type == PlatformType.android ? "a" : "mock");
  final mode = forCrash ? "crash" : "log";

  return "blokada-${platform}6.$mode";
}
