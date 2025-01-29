import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/app/channel.pg.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/plus/module/gateway/gateway.dart';
import 'package:common/plus/module/keypair/keypair.dart';
import 'package:common/plus/module/lease/lease.dart';
import 'package:common/plus/module/vpn/vpn.dart';

part 'actor.dart';
part 'command.dart';

class PlusEnabledValue extends BoolPersistedValue {
  PlusEnabledValue() : super("plus:active");
}

@PlatformProvided()
abstract class PlusChannel
    with GatewayChannel, KeypairChannel, LeaseChannel, VpnChannel {
  Future<void> doPlusEnabledChanged(bool plusEnabled);
}

class PlusModule with Module {
  @override
  onCreateModule() async {
    await register(GatewayModule());
    await register(KeypairModule());
    await register(LeaseModule());
    await register(VpnModule());

    await register(PlusEnabledValue());
    await register(PlusActor());
    await register(PlusCommand());
  }
}
