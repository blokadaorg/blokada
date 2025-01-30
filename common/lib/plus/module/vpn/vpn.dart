import 'dart:async';

import 'package:common/core/core.dart';
import 'package:common/platform/app/app.dart';

part 'actor.dart';
part 'model.dart';

@PlatformProvided()
mixin VpnChannel {
  Future<void> doSetVpnConfig(VpnConfig config);
  Future<void> doSetVpnActive(bool active);
}

@PlatformProvided()
mixin VpnInChannel {
  Future<void> onVpnStatus(VpnStatus status);
}

class CurrentVpnStatusValue extends Value<VpnStatus> {
  CurrentVpnStatusValue() : super(load: () => VpnStatus.unknown);
}

class VpnModule with Module {
  @override
  onCreateModule() async {
    await register(CurrentVpnStatusValue());
    await register(VpnActor());
  }
}
