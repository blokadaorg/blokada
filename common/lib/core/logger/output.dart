part of '../core.dart';

final defaultLoggerPrinter = PrefixPrinter(PrettyPrinter(
  //colors: PlatformInfo().getCurrentPlatformType() != PlatformType.iOS,
  colors: false,
  printEmojis: false,
  stackTraceBeginIndex: 0,
  methodCount: kReleaseMode ? 2 : 6,
  errorMethodCount: 16,
  dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  excludePaths: [
    "package:common/core/logger",
    "<asynchronous suspension>",
  ],
));
