import 'package:common/core/core.dart';
import 'package:common/platform/persistence/channel.pg.dart';

part 'channel.dart';

class PlatformPersistenceModule with Module {
  @override
  onCreateModule() async {
    if (Core.act.isProd) {
      await register<PersistenceChannel>(PlatformPersistenceChannel());
    } else {
      await register<PersistenceChannel>(RuntimePersistenceChannel());
    }

    await register(Persistence(isSecure: false));
    await register(Persistence(isSecure: true), tag: Persistence.secure);
  }
}
