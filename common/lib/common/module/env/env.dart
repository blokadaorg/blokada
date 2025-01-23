import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';

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
