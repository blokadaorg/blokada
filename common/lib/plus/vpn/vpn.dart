import 'dart:async';

import 'package:common/util/async.dart';
import 'package:mobx/mobx.dart';

import '../../app/app.dart';
import '../../timer/timer.dart';
import '../../util/config.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'vpn.g.dart';

enum VpnStatus {
  unknown,
  initializing,
  reconfiguring,
  deactivated,
  paused,
  activated
}

extension VpnStatusExt on VpnStatus {
  isReady() =>
      this == VpnStatus.activated ||
      this == VpnStatus.paused ||
      this == VpnStatus.deactivated;
  isActive() => this == VpnStatus.activated;
}

extension on String {
  VpnStatus toVpnStatus() {
    switch (this) {
      case "initializing":
        return VpnStatus.initializing;
      case "reconfiguring":
        return VpnStatus.reconfiguring;
      case "deactivated":
        return VpnStatus.deactivated;
      case "paused":
        return VpnStatus.paused;
      case "activated":
        return VpnStatus.activated;
      default:
        return VpnStatus.unknown;
    }
  }
}

extension on VpnConfig {
  bool isSame(VpnConfig other) {
    return devicePrivateKey == other.devicePrivateKey &&
        deviceTag == other.deviceTag &&
        gatewayPublicKey == other.gatewayPublicKey &&
        gatewayNiceName == other.gatewayNiceName &&
        gatewayIpv4 == other.gatewayIpv4 &&
        gatewayIpv6 == other.gatewayIpv6 &&
        gatewayPort == other.gatewayPort &&
        leaseVip4 == other.leaseVip4 &&
        leaseVip6 == other.leaseVip6;
  }
}

const String _keyTimer = "vpn:timeout";

class PlusVpnStore = PlusVpnStoreBase with _$PlusVpnStore;

abstract class PlusVpnStoreBase with Store, Traceable, Dependable {
  late final _ops = dep<PlusVpnOps>();
  late final _timer = dep<TimerService>();
  late final _app = dep<AppStore>();

  PlusVpnStoreBase() {
    _onTimerFired();
  }

  @override
  attach(Act act) {
    depend<PlusVpnOps>(getOps(act));
    depend<PlusVpnStore>(this as PlusVpnStore);
  }

  @observable
  VpnStatus actualStatus = VpnStatus.unknown;

  @observable
  VpnStatus targetStatus = VpnStatus.unknown;

  @observable
  VpnConfig? actualConfig;

  @observable
  VpnConfig? targetConfig;

  Completer? _statusCompleter;

  bool _settingConfig = false;

  @action
  Future<void> setVpnConfig(Trace parentTrace, VpnConfig config) async {
    return await traceWith(parentTrace, "setVpnConfig", (trace) async {
      if (actualConfig != null && config.isSame(actualConfig!)) {
        return;
      }

      targetConfig = config;
      if (!actualStatus.isReady() || _settingConfig) {
        trace.addEvent("event queued");
        return;
      }

      _settingConfig = true;
      var attempts = 3;
      while (attempts-- > 0) {
        try {
          await _ops.doSetVpnConfig(config);
          attempts = 0;
          _settingConfig = false;
        } catch (e) {
          if (attempts > 0) {
            trace.addEvent("Failed setting VPN config: $e");
            await sleepAsync(const Duration(seconds: 3));
          } else {
            _settingConfig = false;
            rethrow;
          }
        }
      }

      actualConfig = config;
    }, important: true);
  }

  @action
  Future<void> turnVpnOn(Trace parentTrace) async {
    return await traceWith(parentTrace, "turnVpnOn", (trace) async {
      targetStatus = VpnStatus.activated;
      if (!actualStatus.isReady()) {
        trace.addEvent("event queued");
        return;
      } else if (actualStatus == targetStatus) {
        return;
      }

      await _setActive(true);
    }, important: true);
  }

  @action
  Future<void> turnVpnOff(Trace parentTrace) async {
    return await traceWith(parentTrace, "turnVpnOff", (trace) async {
      targetStatus = VpnStatus.deactivated;
      if (!actualStatus.isReady()) {
        trace.addEvent("event queued");
        return;
      } else if (actualStatus == targetStatus) {
        return;
      }

      await _setActive(false);
    }, important: true);
  }

  @action
  Future<void> setActualStatus(Trace parentTrace, String statusString) async {
    return await traceWith(parentTrace, "setActualStatus", (trace) async {
      final status = statusString.toVpnStatus();
      trace.addAttribute("status", status.name);

      actualStatus = status;
      if (!actualStatus.isReady()) {
        await _app.reconfiguring(trace);
        return;
      }

      // Done working, fire up any queued events.
      final targetCfg = targetConfig;
      final actualCfg = actualConfig;
      if (targetCfg != null &&
          (actualCfg == null || !targetCfg.isSame(actualCfg))) {
        await setVpnConfig(trace, targetCfg);
        trace.addAttribute("eventProcessed", "setVpnConfig");
      }

      // Finish the ongoing completer or keep trying
      if (targetStatus == actualStatus) {
        _statusCompleter?.complete();
        _statusCompleter = null;
        await _app.plusActivated(trace, status.isActive());
      } else if (targetStatus == VpnStatus.unknown) {
        _statusCompleter?.complete();
        _statusCompleter = null;
        await _app.plusActivated(trace, status.isActive());
      } else {
        _statusCompleter
            ?.completeError("VPN returned unexpected status: $status");
        _statusCompleter = null;
        if (targetStatus == VpnStatus.activated) {
          await turnVpnOn(trace);
        } else {
          await turnVpnOff(trace);
        }
        trace.addAttribute("eventProcessed", "setVpnActive");
      }
    }, important: true);
  }

  _setActive(bool active) async {
    _startCommandTimeout();
    _statusCompleter = Completer();
    try {
      await _ops.doSetVpnActive(active);
      await _statusCompleter?.future;
      _statusCompleter = null;
      _stopCommandTimeout();
    } catch (_) {
      _stopCommandTimeout();
      rethrow;
    }
  }

  _startCommandTimeout() {
    _timer.set(_keyTimer, DateTime.now().add(cfg.plusVpnCommandTimeout));
  }

  _stopCommandTimeout() {
    _timer.unset(_keyTimer);
  }

  _onTimerFired() {
    _timer.addHandler(_keyTimer, (trace) async {
      // doSetVpnActive command never finished
      trace.addEvent("setting statusCompleter to fail");
      _statusCompleter?.completeError(Exception("VPN command timed out"));
      _statusCompleter = null;
    });
  }
}
