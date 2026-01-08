import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/perm/channel.pg.dart';
import 'package:common/src/platform/perm/dnscheck.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/features/plus/domain/plus.dart';
import 'package:flutter/cupertino.dart';

part 'actor.dart';
part 'channel.dart';
part 'value.dart';

class PlatformPermModule with Module {
  @override
  Future<void> onCreateModule() async {
    await register(PrivateDnsEnabledForValue());
    await register(NotificationEnabledValue());
    await register(VpnEnabledValue());
    await register(PlatformPermActor());

    if (Core.act.isProd) {
      await register<PermChannel>(PlatformPermChannel());
    } else {
      await register<PermChannel>(NoOpPermChannel());
    }
  }
}

// A temporary interface until family Perm module is included into v6
// and onboard modules are merged

abstract class PrivateDnsStringProvider {
  String getAndroidDnsString();
}
