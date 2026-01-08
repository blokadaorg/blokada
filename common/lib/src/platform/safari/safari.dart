import 'package:common/src/features/safari/domain/safari.dart';
import 'package:common/src/core/core.dart';

import 'channel.pg.dart';

part 'channel.dart';

class PlatformSafariModule with Module {
  @override
  Future<void> onCreateModule() async {
    if (Core.act.isProd) {
      await register<SafariChannel>(PlatformSafariChannel());
    } else {
      await register<SafariChannel>(NoOpSafariChannel());
    }
  }
}
