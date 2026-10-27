import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/perm/channel.pg.dart';
import 'package:common/src/platform/perm/dnscheck.dart';

/// What the Android Private DNS setup sheet shows.
enum PrivateDnsSetupStep { setup, success }

/// Phone makers whose Settings layout differs enough to need their own steps.
enum PrivateDnsOem { samsung, xiaomi, pixel, oneplus, other }

/// Maps `Build.MANUFACTURER` to the steps we show. Redmi and POCO phones
/// report Xiaomi; Google covers Pixel and other stock Android phones.
PrivateDnsOem privateDnsOemFor(String? manufacturer) {
  final m = (manufacturer ?? "").trim().toLowerCase();
  if (m.contains("samsung")) return PrivateDnsOem.samsung;
  if (m.contains("xiaomi") || m.contains("redmi") || m.contains("poco")) {
    return PrivateDnsOem.xiaomi;
  }
  if (m.contains("oneplus")) return PrivateDnsOem.oneplus;
  if (m.contains("google")) return PrivateDnsOem.pixel;
  return PrivateDnsOem.other;
}

/// Picks the setup sheet's step from the live Private DNS setting. A hostname
/// for this device's tag is success; anything else, including a Blokada
/// hostname left from another install, shows the setup steps.
class PrivateDnsSetupVerifier {
  final PermChannel _channel;

  PrivateDnsSetupVerifier({PermChannel? channel}) : _channel = channel ?? Core.get<PermChannel>();

  Future<PrivateDnsSetupStep> verify(DeviceTag tag) async {
    final state = await _channel.getPrivateDnsState();
    final host = state.serverUrl ?? "";
    if (state.kind == PrivateDnsStateKind.enabled &&
        PrivateDnsCheck.isAndroidHostnameForTag(host, tag)) {
      return PrivateDnsSetupStep.success;
    }
    return PrivateDnsSetupStep.setup;
  }
}
