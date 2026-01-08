import 'package:common/src/core/core.dart';
import 'package:common/src/platform/family/channel.pg.dart';

part 'channel.dart';

class PlatformFamilyModule with Logging, Module {
  @override
  onCreateModule() async {
    if (Core.act.isProd) {
      await register<FamilyChannel>(PlatformFamilyChannel());
    } else {
      await register<FamilyChannel>(NoOpFamilyChannel());
    }
  }
}
