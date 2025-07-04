import 'package:common/common/module/safari/safari.dart';
import 'package:common/core/core.dart';

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
