import 'package:common/common/module/lock/lock.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/core/channel.pg.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:logger/logger.dart';

part 'channel.dart';
part 'command.dart';

class PlatformCoreModule with Logging, Module {
  @override
  onCreateModule() async {
    CoreChannel channel;

    if (Core.act.isProd) {
      channel = PlatformCoreChannel();
    } else {
      channel = RuntimeCoreChannel();
    }

    await register<PersistenceChannel>(channel);
    await register<LoggerChannel>(channel);

    await register(Logger(
      filter: ProductionFilter(),
      printer: defaultLoggerPrinter,
      output: FileLoggerOutput(),
    ));

    await register(LogTracerActor());
    await register(LoggerCommand());
  }
}
