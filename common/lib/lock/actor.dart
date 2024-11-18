import 'package:common/core/core.dart';
import 'package:common/lock/lock.dart';
import 'package:common/lock/value.dart';

class LockActor with Actor {
  @override
  onRegister(Act act) {
    DI.register<IsLocked>(IsLocked());
    DI.register<HasPin>(HasPin());
    DI.register<ExistingPin>(ExistingPin());

    final lock = Lock();
    lock.register(act);

    DI.register<Lock>(lock);
  }
}
