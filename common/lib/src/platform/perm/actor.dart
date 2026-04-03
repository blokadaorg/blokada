part of 'perm.dart';

class PlatformPermActor with Logging, Actor {
  static const _iosDeferredDnsRecheckJobName = "platform-perm:ios-dns-recheck";
  static const _iosDeferredDnsRecheckDelay = Duration(milliseconds: 500);
  static const _iosDeferredDnsRecheckMaxAttempts = 3;

  late final _channel = Core.get<PermChannel>();
  late final _dnsEnabledFor = Core.get<PrivateDnsEnabledForValue>();
  late final _notificationEnabled = Core.get<NotificationEnabledValue>();
  late final _vpnEnabled = Core.get<VpnEnabledValue>();

  late final _app = Core.get<AppStore>();
  late final _device = Core.get<DeviceStore>();
  late final _plus = Core.get<PlusActor>();
  late final _scheduler = Core.get<Scheduler>();
  late final _stage = Core.get<StageStore>();
  late final _check = Core.get<PrivateDnsCheck>();

  @override
  onCreate(Marker m) async {
    _stage.addOnValue(routeChanged, onRouteChanged);
    _device.addOn(deviceChanged, onDeviceChanged);

    if (_stage.route.isForeground()) {
      await syncPerms(m);
    }
  }

  bool get isPrivateDnsEnabled {
    return _device.deviceTag != null && _dnsEnabledFor.present == _device.deviceTag;
  }

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
        await _app.cloudPermEnabled(m, tag == _device.deviceTag);
      }
    });
  }

  Future<void> setPrivateDnsDisabled(Marker m) async {
    return await log(m).trace("privateDnsDisabled", (m) async {
      if (_dnsEnabledFor.present != null) {
        await _dnsEnabledFor.change(m, null);
        await _app.cloudPermEnabled(m, false);
      }
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
          if (!Core.act.isFamily) {
            await _plus.reactToPlusLost(m, "VPN perm disabled");
          }
          await _app.plusActivated(false, m);
        }
        await _app.plusPermEnabled(enabled, m);
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
        _previousTag = tag;
        _previousAlias = _device.deviceAlias;
        await _scheduler.stop(m, _iosDeferredDnsRecheckJobName);
        await _beginForegroundDnsVerification(tag, m);

        if (!Core.act.isFamily) {
          try {
            await _channel.doSetPrivateDnsEnabled(tag, _device.deviceAlias);
            await _recheckDnsPerm(tag, m);
          } catch (e) {
            log(m).e(msg: "DNS permission check failed, settling", err: e);
            await _app.cloudPermCheckSettled(m, true);
            rethrow;
          }
        }

        await _recheckVpnPerm(m);
      }
    });
  }

  Future<void> syncPerms(Marker m) async {
    return await log(m).trace("syncPerms", (m) async {
      await _scheduler.stop(m, _iosDeferredDnsRecheckJobName);
      final tag = _device.deviceTag;
      if (tag != null) {
        await _beginForegroundDnsVerification(tag, m);
        try {
          await _recheckDnsPerm(tag, m);
        } catch (e) {
          log(m).e(msg: "DNS permission check failed, settling", err: e);
          await _app.cloudPermCheckSettled(m, true);
          rethrow;
        }
        await _recheckVpnPerm(m);
      } else {
        await _app.cloudPermCheckSettled(m, true);
      }
    });
  }

  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isForeground()) {
      await _scheduler.stop(m, _iosDeferredDnsRecheckJobName);
      await _app.cloudPermCheckSettled(m, true);
      return;
    }

    if (!(route.isBecameForeground() /* || route.modal == StageModal.perms*/)) {
      return;
    }

    return await log(m).trace("checkPermsOnFg", (m) async {
      await syncPerms(m);
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

  _recheckDnsPerm(DeviceTag tag, Marker m, {int attempt = 0}) async {
    final currentTag = _device.deviceTag;
    if (currentTag == null || currentTag != tag) {
      await _app.cloudPermCheckSettled(m, true);
      return;
    }

    // Use API check on macOS, local check on iOS/iPadOS
    final isOnMac = await _channel.isRunningOnMac();
    String source;
    String current = "(api-check)";
    bool isEnabled;
    if (isOnMac) {
      source = "api";
      isEnabled = await _check.checkPrivateDnsEnabledWithApi(m, _device.deviceTag!);
    } else {
      source = "system";
      final dnsState = await _channel.getPrivateDnsState();
      current = _describePrivateDnsState(dnsState);
      if (_shouldDeferPrivateDnsState(tag, dnsState, attempt)) {
        await _scheduleDeferredDnsRecheck(tag, attempt + 1, m);
        log(m).log(
          msg: "[NetDiag] privateDnsCheckDeferred",
          attr: {
            "source": source,
            "attempt": attempt,
            "currentDns": current,
            "expectedTag": _device.deviceTag,
            "deviceAlias": _device.deviceAlias,
            "privateDnsEnabledFor": _dnsEnabledFor.present,
            "result": "deferred",
          },
        );
        return;
      }
      isEnabled = _isPrivateDnsStateEnabled(m, dnsState, _device.deviceTag!, _device.deviceAlias);
    }

    log(m).log(
      msg: "[NetDiag] privateDnsCheck",
      attr: {
        "source": source,
        "attempt": attempt,
        "currentDns": current,
        "expectedTag": _device.deviceTag,
        "deviceAlias": _device.deviceAlias,
        "privateDnsEnabledFor": _dnsEnabledFor.present,
        "result": isEnabled ? "enabled" : "disabled",
      },
    );

    if (isEnabled) {
      await setPrivateDnsEnabled(tag, m);
    } else {
      await setPrivateDnsDisabled(m);
    }

    await _app.cloudPermCheckSettled(m, true);
  }

  _recheckVpnPerm(Marker m) async {
    final isEnabled = await _channel.doVpnEnabled();
    await setVpnPermEnabled(isEnabled, m);
  }

  bool _shouldDeferPrivateDnsState(DeviceTag tag, PrivateDnsState state, int attempt) {
    if (!Core.act.isIos || _isPrivateDnsStateDecisive(state)) {
      return false;
    }

    if (!_shouldTrackForegroundDnsVerification(tag)) {
      return false;
    }

    return attempt < _iosDeferredDnsRecheckMaxAttempts;
  }

  bool _isPrivateDnsStateEnabled(
    Marker m,
    PrivateDnsState state,
    DeviceTag tag,
    String alias,
  ) {
    if (state.kind != PrivateDnsStateKind.enabled) {
      return false;
    }

    final current = state.serverUrl;
    if (current == null || current.isEmpty) {
      return false;
    }

    return _check.isCorrect(m, current, tag, alias);
  }

  bool _isPrivateDnsStateDecisive(PrivateDnsState state) {
    switch (state.kind) {
      case PrivateDnsStateKind.disabled:
        return true;
      case PrivateDnsStateKind.enabled:
        final current = state.serverUrl;
        return current != null && current.isNotEmpty;
      case PrivateDnsStateKind.unavailable:
        return false;
    }
  }

  String _describePrivateDnsState(PrivateDnsState state) {
    final serverUrl = state.serverUrl;
    switch (state.kind) {
      case PrivateDnsStateKind.enabled:
        return serverUrl?.isNotEmpty == true
            ? "enabled:$serverUrl"
            : "enabled:(missing-url)";
      case PrivateDnsStateKind.disabled:
        return serverUrl?.isNotEmpty == true
            ? "disabled:$serverUrl"
            : "disabled";
      case PrivateDnsStateKind.unavailable:
        return serverUrl?.isNotEmpty == true
            ? "unavailable:$serverUrl"
            : "unavailable";
    }
  }

  bool _shouldTrackForegroundDnsVerification(DeviceTag tag) {
    if (Core.act.isFamily) {
      return false;
    }

    if (!_stage.route.isForeground() || !_stage.route.isMainRoute()) {
      return false;
    }

    if (_device.deviceTag != tag) {
      return false;
    }

    if (_device.cloudEnabled != true) {
      return false;
    }

    return _app.conditions.accountIsCloud;
  }

  Future<void> _beginForegroundDnsVerification(DeviceTag tag, Marker m) async {
    await _app.cloudPermCheckSettled(
      m,
      !_shouldTrackForegroundDnsVerification(tag),
    );
  }

  Future<void> _scheduleDeferredDnsRecheck(DeviceTag tag, int attempt, Marker m) async {
    await _scheduler.addOrUpdate(
      Job(
        _iosDeferredDnsRecheckJobName,
        m,
        before: _scheduler.timer.now().add(_iosDeferredDnsRecheckDelay),
        when: [Conditions.foreground],
        callback: (jobMarker) async {
          final currentTag = _device.deviceTag;
          if (currentTag == null || currentTag != tag) {
            await _app.cloudPermCheckSettled(jobMarker, true);
            return false;
          }

          if (!_shouldTrackForegroundDnsVerification(tag)) {
            await _app.cloudPermCheckSettled(jobMarker, true);
            return false;
          }

          await _recheckDnsPerm(tag, jobMarker, attempt: attempt);
          return false;
        },
      ),
    );
  }

  askNotificationPermissions(Marker m, {bool checkForPerms = false}) async {
    if (checkForPerms && await _channel.doNotificationEnabled()) {
      return;
    }

    await _channel.doAskNotificationPerms();
  }
}
