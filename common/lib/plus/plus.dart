import 'package:common/common/module/modal/modal.dart';
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
import 'package:common/plus/widget/device_limit_sheet.dart';

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
  Submodules onRegisterSubmodules() async => [
        KeypairModule(),
        GatewayModule(),
        LeaseModule(),
        VpnModule(),
      ];

  @override
  onCreateModule() async {
    await register(PlusEnabledValue());
    await register(PlusActor());
    await register(PlusCommand());
    await register(PlusSheetActor());
  }
}

class PlusSheetActor with Actor {
  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  @override
  onCreate(Marker m) async {
    // Provide the widget factory for the modal this module handles
    _modal.onChange.listen((it) {
      if (it.now == Modal.plusDeviceLimitReached) {
        _modalWidget.change(it.m, (context) => const DeviceLimitSheet());
      }
    });
  }
}
