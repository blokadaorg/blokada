import 'package:common/core/core.dart';
import 'package:common/family/module/perm/perm.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/perm/channel.pg.dart';
import 'package:common/platform/perm/dnscheck.dart';
import 'package:common/platform/plus/plus.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';

part 'actor.dart';
part 'channel.dart';
part 'value.dart';

class PlatformPermModule with Module {
  @override
  Future<void> onCreateModule() async {
    await register(PrivateDnsEnabledFor());
    await register(NotificationEnabled());
    await register(VpnEnabled());
    await register(PlatformPermActor());

    if (Core.act.isProd) {
      await register<PermChannel>(PlatformPermChannel());
    } else {
      await register<PermChannel>(NoOpPermChannel());
    }
  }
}
