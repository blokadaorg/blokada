import 'package:common/src/features/lock/domain/lock.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/core/channel.pg.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:logger/logger.dart';

part 'channel.dart';
part 'command.dart';

class PlatformCoreModule with Logging, Module {
  @override
  onCreateModule() async {
    CoreChannel channel;

    // Mocked scenario also uses real iOS storage: the secure-storage seeded
    // account must survive across reads, and other state (config, lock pin,
    // support unread, etc.) must persist between launches. RuntimeCoreChannel
    // is only for unit tests where the platform host is unavailable.
    if (Core.act.isProd || Core.act.isMocked) {
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
