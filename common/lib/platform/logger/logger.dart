import 'package:common/core/core.dart';
import 'package:common/platform/logger/channel.act.dart';
import 'package:common/platform/logger/channel.pg.dart';
import 'package:logger/logger.dart';

class FileLoggerOutput extends LogOutput {
  late final _ops = dep<LoggerOps>();
  late Act _act;

  FileLoggerOutput(Act act) {
    _act = act;
    const template = '''
\t\t\t
''';
    _ops.doUseFilename(getLogFilename());
  }

  String getLogFilename() {
    final type = PlatformInfo().getCurrentPlatformType();
    final platform = type == PlatformType.iOS
        ? "i"
        : (type == PlatformType.android ? "a" : "z");
    final flavor = _act.isFamily ? "F" : "6";
    final build = _act.isRelease ? "R" : "D";

    return "blokada-$platform${flavor}x$build.log";
  }

  @override
  void output(OutputEvent event) {
    // if (kReleaseMode) {
    //   developer.log(
    //     "\n${event.lines.join("\n")}",
    //     time: event.origin.time,
    //     level: event.level.value,
    //   );
    // } else {
    for (var line in event.lines) {
      print(line);
    }
    // }

    // Save batch to file
    if (event.level == Level.trace && _act.isRelease) return;
    _ops.doSaveBatch("${event.lines.join("\n")}\n");
  }
}

class LoggerCommands with Logging, Actor {
  late final _ops = dep<LoggerOps>();

  @override
  void onRegister(Act act) {
    depend<LoggerOps>(getOps(act));
    depend<Logger>(Logger(
      filter: ProductionFilter(),
      printer: defaultLoggerPrinter,
      output: FileLoggerOutput(act),
    ));
    LogTracer().register(act);
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
