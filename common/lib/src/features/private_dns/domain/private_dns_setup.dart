import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/perm/channel.pg.dart';
import 'package:common/src/platform/perm/dnscheck.dart';

/// What the Android Private DNS setup sheet shows.
enum PrivateDnsSetupStep { setup, checking, success, help }

/// Why the help step is shown. Used for logging and tests.
enum PrivateDnsHelpReason { wrongHostname, broken, notRouted }

class PrivateDnsSetupResult {
  final PrivateDnsSetupStep step;
  final PrivateDnsHelpReason? reason;

  const PrivateDnsSetupResult(this.step, [this.reason]);

  @override
  String toString() => "$step${reason != null ? "($reason)" : ""}";
}

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

/// Confirms that Private DNS on Android really goes through Blokada, so the
/// setup sheet only says "done" when it is. A matching hostname alone is not
/// enough: the network can block Private DNS, or the system may fail to reach
/// it. So a match is followed by the live `getDnsOwnerFlavor` probe.
class PrivateDnsSetupVerifier with Logging {
  final PermChannel _channel;
  final PrivateDnsCheck _check;
  final int probeAttempts;
  final Duration probeDelay;

  PrivateDnsSetupVerifier({
    PermChannel? channel,
    PrivateDnsCheck? check,
    this.probeAttempts = 3,
    this.probeDelay = const Duration(seconds: 2),
  }) : _channel = channel ?? Core.get<PermChannel>(),
       _check = check ?? Core.get<PrivateDnsCheck>();

  /// [attempted] is true once the user went to Settings from the sheet. Only
  /// then a non-Blokada hostname counts as a mistake worth the help step;
  /// before that it is just the DNS they had, and the setup steps apply.
  /// [onChecking] fires when the hostname matched and the slower live probe
  /// starts, so the sheet can show progress only when there is some.
  Future<PrivateDnsSetupResult> verify(
    Marker m,
    DeviceTag tag, {
    required bool attempted,
    void Function()? onChecking,
  }) async {
    final state = await _channel.getPrivateDnsState();
    final host = state.serverUrl ?? "";
    if (state.kind != PrivateDnsStateKind.enabled || host.isEmpty) {
      return const PrivateDnsSetupResult(PrivateDnsSetupStep.setup);
    }

    if (!PrivateDnsCheck.isAndroidHostnameForTag(host, tag)) {
      if (attempted || PrivateDnsCheck.isBlokadaHostname(host)) {
        return const PrivateDnsSetupResult(
          PrivateDnsSetupStep.help,
          PrivateDnsHelpReason.wrongHostname,
        );
      }
      return const PrivateDnsSetupResult(PrivateDnsSetupStep.setup);
    }

    onChecking?.call();

    // Android validates the new server for a few seconds after it is set,
    // and lookups fail meanwhile, so retry before giving up.
    for (var attempt = 1; attempt <= probeAttempts; attempt++) {
      try {
        final owner = await _check.getDnsOwnerFlavor(m, fresh: true);
        if (owner != null) {
          return const PrivateDnsSetupResult(PrivateDnsSetupStep.success);
        }
        log(m).w("Private DNS probe: not routed (attempt $attempt)");
      } catch (e) {
        log(m).e(msg: "Private DNS probe failed (attempt $attempt)", err: e);
      }
      if (attempt < probeAttempts) await sleepAsync(probeDelay);
    }

    // The system flag can lag right after a change, so it only names the
    // reason; the probe decides.
    final broken = state.privateDnsBroken == true;
    return PrivateDnsSetupResult(
      PrivateDnsSetupStep.help,
      broken ? PrivateDnsHelpReason.broken : PrivateDnsHelpReason.notRouted,
    );
  }
}
