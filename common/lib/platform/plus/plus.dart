import 'package:common/core/core.dart';
import 'package:common/platform/plus/channel.pg.dart';
import 'package:common/plus/module/gateway/gateway.dart';
import 'package:common/plus/module/keypair/keypair.dart';
import 'package:common/plus/module/lease/lease.dart';
import 'package:common/plus/module/vpn/vpn.dart';
import 'package:common/plus/plus.dart';

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

    await register<PlusChannel>(channel);
  }
}
