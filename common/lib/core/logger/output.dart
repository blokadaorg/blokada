part of '../core.dart';

final defaultLoggerPrinter = PrefixPrinter(PrettyPrinter(
  //colors: PlatformInfo().getCurrentPlatformType() != PlatformType.iOS,
  colors: false,
  printEmojis: false,
  stackTraceBeginIndex: 0,
  methodCount: 2,
  errorMethodCount: 16,
  dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  excludePaths: ["package:common/logger"],
));
