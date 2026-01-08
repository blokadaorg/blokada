import 'package:common/src/core/core.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:string_validator/string_validator.dart';

part 'actor.dart';

class IsLocked extends Value<bool> {
  IsLocked() : super(load: () => false);
}

class HasPin extends Value<bool> {
  HasPin() : super(load: () => false);
}

class ExistingPin extends StringPersistedValue {
  ExistingPin() : super("lock:pin");
}

class LockModule with Module {
  @override
  onCreateModule() async {
    await register(IsLocked());
    await register(HasPin());
    await register(ExistingPin());
    await register(LockActor());
  }
}
