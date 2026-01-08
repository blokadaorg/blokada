import 'package:common/src/core/core.dart';
import 'package:common/src/platform/plus/channel.pg.dart';
import 'package:common/src/features/plus/domain/bypass/bypass.dart';
import 'package:common/src/features/plus/domain/gateway/gateway.dart';
import 'package:common/src/features/plus/domain/keypair/keypair.dart';
import 'package:common/src/features/plus/domain/lease/lease.dart';
import 'package:common/src/features/plus/domain/vpn/vpn.dart';
import 'package:common/src/features/plus/domain/plus.dart';
import 'package:flutter/foundation.dart';

part 'channel.dart';

class PlatformPlusModule with Logging, Module {
  @override
  onCreateModule() async {
    PlusChannel channel;

    if (Core.act.isProd) {
      channel = PlatformPlusChannel();
    } else {
      channel = NoOpPlusChannel();
    }

    await register<KeypairChannel>(channel);
    await register<GatewayChannel>(channel);
    await register<LeaseChannel>(channel);
    await register<VpnChannel>(channel);
    await register<BypassChannel>(channel);

    await register<PlusChannel>(channel);
  }
}
