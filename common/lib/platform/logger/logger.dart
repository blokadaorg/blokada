import 'package:common/core/core.dart';
import 'package:common/lock/lock.dart';
import 'package:common/platform/logger/channel.pg.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:logger/logger.dart';

part 'channel.dart';
part 'command.dart';
part 'output.dart';

class PlatformLoggerModule with Logging, Module {
  @override
  onCreateModule(Act act) async {
    if (act.isProd) {
      await register<LoggerChannel>(PlatformLoggerChannel());
    } else {
      await register<LoggerChannel>(NoOpLoggerChannel());
    }

    await register(Logger(
      filter: ProductionFilter(),
      printer: defaultLoggerPrinter,
      output: FileLoggerOutput(act),
    ));

    await register(LogTracerActor());
    await register(LoggerCommand());
  }
}
