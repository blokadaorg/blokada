import 'package:common/core/core.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:string_validator/string_validator.dart';

part 'actor.dart';
part 'value.dart';

class LockModule with Module {
  @override
  onCreateModule() async {
    await register(IsLocked());
    await register(HasPin());
    await register(ExistingPin());
    await register(LockActor());
  }
}
