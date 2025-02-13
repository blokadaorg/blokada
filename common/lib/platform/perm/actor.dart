part of 'perm.dart';

class PlatformPermActor with Logging, Actor {
  late final _channel = Core.get<PermChannel>();
  late final _dnsEnabledFor = Core.get<PrivateDnsEnabledFor>();
  late final _notificationEnabled = Core.get<NotificationEnabled>();
  late final _vpnEnabled = Core.get<VpnEnabled>();

  late final _app = Core.get<AppStore>();
  late final _device = Core.get<DeviceStore>();
  late final _plus = Core.get<PlusActor>();
  late final _stage = Core.get<StageStore>();
  late final _check = Core.get<PrivateDnsCheck>();

  @override
  onCreate(Marker m) async {
    _stage.addOnValue(routeChanged, onRouteChanged);
    _app.addOn(appStatusChanged, onAppStatusChanged);
    _device.addOn(deviceChanged, onDeviceChanged);
  }

  bool get isPrivateDnsEnabled {
    return _device.deviceTag != null &&
        _dnsEnabledFor.present == _device.deviceTag;
  }

  int _privateDnsTagChangeCounter = 0;

  DeviceTag? _previousTag;
  String? _previousAlias;

  authenticate(Marker m, VoidCallback fn) async {
    if (await _channel.doAuthenticate()) {
      fn();
    }
  }

  Future<void> setPrivateDnsEnabled(DeviceTag tag, Marker m) async {
    return await log(m).trace("privateDnsEnabled", (m) async {
      log(m).pair("tag", tag);

      if (tag != _dnsEnabledFor.present) {
        await _dnsEnabledFor.change(m, tag);
        await _app.cloudPermEnabled(tag == _device.deviceTag, m);
      }
    });
  }

  Future<void> setPrivateDnsDisabled(Marker m) async {
    return await log(m).trace("privateDnsDisabled", (m) async {
      if (_dnsEnabledFor.present != null) {
        await _dnsEnabledFor.change(m, null);
        await _app.cloudPermEnabled(false, m);
      }
    });
  }

  Future<void> incrementPrivateDnsTagChangeCounter(Marker m) async {
    return await log(m).trace("incrementPrivateDnsTagChangeCounter", (m) async {
      _privateDnsTagChangeCounter += 1;
    });
  }

  Future<void> setNotificationEnabled(bool enabled, Marker m) async {
    return await log(m).trace("notificationEnabled", (m) async {
      if (enabled != _notificationEnabled.present) {
        await _notificationEnabled.change(m, enabled);
      }
    });
  }

  Future<void> setVpnPermEnabled(bool enabled, Marker m) async {
    return await log(m).trace("setVpnPermEnabled", (m) async {
      if (enabled != _vpnEnabled.present) {
        await _vpnEnabled.change(m, enabled);
        if (!enabled) {
          if (!Core.act.isFamily) await _plus.reactToPlusLost(m);
          await _app.plusActivated(false, m);
        }
      }
    });
  }

  // Whenever device tag from backend changes, update the DNS profile in system
  // settings if possible. User is meant to activate it manually, but our app
  // can update it on iOS. Then, recheck the perms.
  Future<void> syncPermsAfterTagChange(String tag, Marker m) async {
    return await log(m).trace("syncPermsAfterTagChange", (m) async {
      if (_previousTag == null ||
          tag != _previousTag ||
          _previousAlias == null ||
          _previousAlias != _device.deviceAlias) {
        incrementPrivateDnsTagChangeCounter;
        _previousTag = tag;
        _previousAlias = _device.deviceAlias;

        if (!Core.act.isFamily) {
          await _channel.doSetPrivateDnsEnabled(tag, _device.deviceAlias);
          await _recheckDnsPerm(tag, m);
        }

        await _recheckVpnPerm(m);
      }
    });
  }

  Future<void> syncPerms(Marker m) async {
    // TODO: check all perms on foreground
    return await log(m).trace("syncPerms", (m) async {
      final tag = _device.deviceTag;
      if (tag != null) {
        await _recheckDnsPerm(tag, m);
        await _recheckVpnPerm(m);
      }
    });
  }

  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!(route.isBecameForeground()/* || route.modal == StageModal.perms*/)) {
      return;
    }

    return await log(m).trace("checkPermsOnFg", (m) async {
      await syncPerms(m);
    });
  }

  Future<void> onAppStatusChanged(Marker m) async {
    return await log(m).trace("onAppStatusChanged", (m) async {
      if (_app.status.isInactive()) {
        await syncPerms(m);
      }
    });
  }

  Future<void> onDeviceChanged(Marker m) async {
    return await log(m).trace("onDeviceChanged", (m) async {
      final tag = _device.deviceTag;
      if (tag != null) await syncPermsAfterTagChange(tag, m);
    });
  }

  bool isPrivateDnsEnabledFor(DeviceTag? tag) {
    return tag != null && _dnsEnabledFor.present == tag;
  }

  _recheckDnsPerm(DeviceTag tag, Marker m) async {
    final current = await _channel.getPrivateDnsSetting();
    final isEnabled =
        _check.isCorrect(m, current, _device.deviceTag!, _device.deviceAlias);

    if (isEnabled) {
      await setPrivateDnsEnabled(tag, m);
    } else {
      await setPrivateDnsDisabled(m);
    }
  }

  _recheckVpnPerm(Marker m) async {
    final isEnabled = await _channel.doVpnEnabled();
    await setVpnPermEnabled(isEnabled, m);
  }

  askNotificationPermissions(Marker m) async {
    await _channel.doAskNotificationPerms();
  }
}
