part of '../core.dart';

final defaultLoggerPrinter = PrefixPrinter(PrettyPrinter(
  //colors: PlatformInfo().getCurrentPlatformType() != PlatformType.iOS,
  colors: false,
  printEmojis: false,
  stackTraceBeginIndex: 0,
  methodCount: kReleaseMode ? 2 : 6,
  errorMethodCount: 16,
  dateTimeFormat: _dateAndTimeAndSinceStart,
  excludePaths: [
    "package:common/src/core/logger",
    "<asynchronous suspension>",
  ],
));

String _dateAndTimeAndSinceStart(DateTime t) {
  String isoDate = t.toIso8601String().replaceFirst("T", " ");
  var timeSinceStart = t.difference(PrettyPrinter.startTime!).toString();
  return "$isoDate (+$timeSinceStart) ${t.timeZoneName}";
}

mixin LoggerChannel {
  Future<void> doUseFilename(String filename);
  Future<void> doSaveBatch(String batch);
  Future<void> doShareFile();
}

class FileLoggerOutput extends LogOutput {
  late final _channel = Core.get<LoggerChannel>();

  FileLoggerOutput() {
    _channel.doUseFilename(getLogFilename());
  }

  String getLogFilename() {
    final type = PlatformInfo().getCurrentPlatformType();
    final platform = type == PlatformType.iOS
        ? "i"
        : (type == PlatformType.android ? "a" : "z");
    final flavor = Core.act.isFamily ? "F" : "6";
    final build = Core.act.isRelease ? "R" : "D";

    return "blokada-$platform${flavor}x$build.log";
  }

  @override
  void output(OutputEvent event) {
    // Debug-only printout to stdout
    for (var line in event.lines) {
      print(line);
    }

    // Save batch to file
    if (event.level == Level.trace && Core.act.isRelease) return;
    // Ideally this should be called with await, but the LogOutput interface
    // does not support it
    _channel.doSaveBatch("${event.lines.join("\n")}\n");
  }
}
