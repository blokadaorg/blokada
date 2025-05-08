part of 'vpn.dart';

const String _keyTimer = "vpn:timeout";
const String _keyOngoingTimer = "vpn:ongoing:timeout";

class VpnActor with Logging, Actor {
  late final _channel = Core.get<VpnChannel>();
  late final _scheduler = Core.get<Scheduler>();
  late final _actualStatus = Core.get<CurrentVpnStatusValue>();

  late final _app = Core.get<AppStore>();

  VpnStatus targetStatus = VpnStatus.unknown;

  VpnConfig? actualConfig;

  VpnConfig? targetConfig;

  Completer? _statusCompleter;

  bool _settingConfig = false;

  setVpnConfig(VpnConfig config, Marker m) async {
    return await log(m).trace("setVpnConfig", (m) async {
      if (actualConfig != null && config.isSame(actualConfig!)) {
        return;
      }

      targetConfig = config;
      if (!_actualStatus.now.isReady() || _settingConfig) {
        log(m).i("event queued");
        return;
      }

      _settingConfig = true;
      var attempts = 3;
      while (attempts-- > 0) {
        try {
          await _channel.doSetVpnConfig(config);
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

  turnVpnOn(Marker m) async {
    return await log(m).trace("turnVpnOn", (m) async {
      targetStatus = VpnStatus.activated;
      if (!_actualStatus.now.isReady()) {
        log(m).i("event queued");
        return;
      } else if (_actualStatus.now == targetStatus) {
        return;
      }

      await _setActive(m, true);
    });
  }

  turnVpnOff(Marker m) async {
    return await log(m).trace("turnVpnOff", (m) async {
      targetStatus = VpnStatus.deactivated;
      if (!_actualStatus.now.isReady()) {
        log(m).i("event queued");
        return;
      } else if (_actualStatus.now == targetStatus) {
        return;
      }

      await _setActive(m, false);
    });
  }

  setActualStatus(String statusString, Marker m) async {
    return await log(m).trace("setActualStatus", (m) async {
      final status = statusString.toVpnStatus();
      log(m).pair("status", status.name);

      _actualStatus.now = status;
      if (!_actualStatus.now.isReady()) {
        await _app.reconfiguring(m);
        await _startOngoingTimeout(m);
        return;
      } else {
        await _stopOngoingTimeout(m);
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
      if (targetStatus == _actualStatus.now) {
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

  _setActive(Marker m, bool active) async {
    await _startCommandTimeout(m);
    _statusCompleter = Completer();
    try {
      await _channel.doSetVpnActive(active);
      await _statusCompleter?.future;
      _statusCompleter = null;
      await _stopCommandTimeout(m);
    } catch (_) {
      await _stopCommandTimeout(m);
      rethrow;
    }
  }

  _startCommandTimeout(Marker m) async {
    await _scheduler.addOrUpdate(Job(
      _keyTimer,
      m,
      before: DateTime.now().add(Core.config.plusVpnCommandTimeout),
      callback: _onTimerFired,
    ));
  }

  _stopCommandTimeout(Marker m) async => await _scheduler.stop(m, _keyTimer);

  Future<bool> _onTimerFired(Marker m) async {
    // doSetVpnActive command never finished
    log(m).i("setting statusCompleter to fail");
    _statusCompleter?.completeError(Exception("VPN command timed out"));
    _statusCompleter = null;
    return false;
  }

  Future<bool> _onOngoingTimerFired(Marker m) async {
    log(m).e(msg: "VPN ongoing status too long");
    await setActualStatus("deactivated", m);
    return false;
  }

  _startOngoingTimeout(Marker m) async {
    await _scheduler.addOrUpdate(Job(
      _keyOngoingTimer,
      m,
      before: DateTime.now().add(Core.config.plusVpnCommandTimeout),
      callback: _onOngoingTimerFired,
    ));
  }

  _stopOngoingTimeout(Marker m) async =>
      await _scheduler.stop(m, _keyOngoingTimer);
}
