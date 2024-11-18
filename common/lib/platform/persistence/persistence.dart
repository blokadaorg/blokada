import 'package:common/core/core.dart';
import 'package:common/platform/persistence/channel.dart';

class PersistenceActor with Actor {
  @override
  onRegister(Act act) {
    if (act.isProd) {
      DI.register<PersistenceChannel>(PlatformPersistenceChannel());
    } else {
      DI.register<PersistenceChannel>(RuntimePersistenceChannel());
    }

    DI.register<Persistence>(Persistence(isSecure: false));
    DI.register<Persistence>(Persistence(isSecure: true),
        tag: Persistence.secure);
  }
}
