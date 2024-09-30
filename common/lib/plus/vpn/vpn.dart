import 'dart:async';

import 'package:common/logger/logger.dart';
import 'package:common/util/async.dart';
import 'package:mobx/mobx.dart';

import '../../app/app.dart';
import '../../timer/timer.dart';
import '../../util/config.dart';
import '../../util/di.dart';
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
const String _keyOngoingTimer = "vpn:ongoing:timeout";

class PlusVpnStore = PlusVpnStoreBase with _$PlusVpnStore;

abstract class PlusVpnStoreBase with Store, Logging, Dependable {
  late final _ops = dep<PlusVpnOps>();
  late final _timer = dep<TimerService>();
  late final _app = dep<AppStore>();

  PlusVpnStoreBase() {
    _onTimerFired();
    _onOngoingTimerFired();
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
  Future<void> setVpnConfig(VpnConfig config, Marker m) async {
    return await log(m).trace("setVpnConfig", (m) async {
      if (actualConfig != null && config.isSame(actualConfig!)) {
        return;
      }

      targetConfig = config;
      if (!actualStatus.isReady() || _settingConfig) {
        log(m).i("event queued");
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
            log(m).i("Failed setting VPN config: $e");
            await sleepAsync(const Duration(seconds: 3));
          } else {
            _settingConfig = false;
            rethrow;
          }
        }
      }

      actualConfig = config;
    });
  }

  @action
  Future<void> turnVpnOn(Marker m) async {
    return await log(m).trace("turnVpnOn", (m) async {
      targetStatus = VpnStatus.activated;
      if (!actualStatus.isReady()) {
        log(m).i("event queued");
        return;
      } else if (actualStatus == targetStatus) {
        return;
      }

      await _setActive(true);
    });
  }

  @action
  Future<void> turnVpnOff(Marker m) async {
    return await log(m).trace("turnVpnOff", (m) async {
      targetStatus = VpnStatus.deactivated;
      if (!actualStatus.isReady()) {
        log(m).i("event queued");
        return;
      } else if (actualStatus == targetStatus) {
        return;
      }

      await _setActive(false);
    });
  }

  @action
  Future<void> setActualStatus(String statusString, Marker m) async {
    return await log(m).trace("setActualStatus", (m) async {
      final status = statusString.toVpnStatus();
      log(m).pair("status", status.name);

      actualStatus = status;
      if (!actualStatus.isReady()) {
        await _app.reconfiguring;
        _startOngoingTimeout();
        return;
      } else {
        _stopOngoingTimeout();
      }

      // Done working, fire up any queued events.
      final targetCfg = targetConfig;
      final actualCfg = actualConfig;
      if (targetCfg != null &&
          (actualCfg == null || !targetCfg.isSame(actualCfg))) {
        await setVpnConfig(targetCfg, m);
        log(m).pair("eventProcessed", "setVpnConfig");
      }

      // Finish the ongoing completer or keep trying
      if (targetStatus == actualStatus) {
        _statusCompleter?.complete();
        _statusCompleter = null;
        await _app.plusActivated(status.isActive(), m);
      } else if (targetStatus == VpnStatus.unknown) {
        _statusCompleter?.complete();
        _statusCompleter = null;
        await _app.plusActivated(status.isActive(), m);
      } else {
        // _statusCompleter
        //     ?.completeError("VPN returned unexpected status: $status");
        // Quietly ignore this error, as we will try again
        // This may be a bit dangerous, but the states on Android are shit,
        // so we have to hope for the best.
        _statusCompleter?.complete();
        _statusCompleter = null;
        if (targetStatus == VpnStatus.activated) {
          await turnVpnOn(m);
        } else {
          await turnVpnOff(m);
        }
        log(m).pair("eventProcessed", "setVpnActive");
      }
    });
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
    _timer.addHandler(_keyTimer, (m) async {
      // doSetVpnActive command never finished
      log(m).i("setting statusCompleter to fail");
      _statusCompleter?.completeError(Exception("VPN command timed out"));
      _statusCompleter = null;
    });
  }

  _onOngoingTimerFired() {
    _timer.addHandler(_keyOngoingTimer, (m) async {
      log(m).i("VPN ongoing status too long");
      await setActualStatus("deactivated", m);
    });
  }

  _startOngoingTimeout() {
    _timer.set(_keyOngoingTimer, DateTime.now().add(cfg.plusVpnCommandTimeout));
  }

  _stopOngoingTimeout() {
    _timer.unset(_keyOngoingTimer);
  }
}
