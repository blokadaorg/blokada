import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:flutter/services.dart';

part 'actor.dart';
part 'model.dart';

/// The OS accepted the start but holds it: iOS does this while it swaps in an
/// updated VPN extension, for up to five minutes, then starts the tunnel by
/// itself. Not a failure to undo.
class VpnStartPendingException implements Exception {
  @override
  String toString() => "VpnStartPendingException";
}

/// The error code iOS returns when the start is held (see WgService.swift).
const _startPendingCode = "vpnStartPending";

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
