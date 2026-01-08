import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';

part 'actor.dart';
part 'model.dart';

@PlatformProvided()
mixin EnvChannel {
  Future<EnvInfo> doGetEnvInfo();
}

class EnvModule with Module {
  @override
  onCreateModule() async {
    await register(EnvActor());
  }
}
