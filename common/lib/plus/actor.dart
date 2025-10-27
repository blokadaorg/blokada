part of 'plus.dart';

class PlusActor with Logging, Actor {
  late final _channel = Core.get<PlusChannel>();
  late final _gateway = Core.get<GatewayActor>();
  late final _lease = Core.get<LeaseActor>();
  late final _vpn = Core.get<VpnActor>();
  late final _plusEnabled = Core.get<PlusEnabledValue>();
  late final _currentKeypair = Core.get<CurrentKeypairValue>();
  late final _currentLease = Core.get<CurrentLeaseValue>();
  late final _currentGateway = Core.get<CurrentGatewayValue>();
  late final _vpnStatus = Core.get<CurrentVpnStatusValue>();
  late final _modal = Core.get<CurrentModalValue>();
  late final _bypassedPackages = Core.get<BypassedPackagesValue>();
  late final _scheduler = Core.get<Scheduler>();

  late final _app = Core.get<AppStore>();
  late final _device = Core.get<DeviceStore>();
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();

  bool _isSwitching = false;

  @override
  onCreate(Marker m) async {
    await _plusEnabled.fetch(m);
  }

  @override
  onStart(Marker m) async {
    return await log(m).trace("start", (m) async {
      _plusEnabled.onChange.listen((change) async {
        await _channel.doPlusEnabledChanged(change.now);
      });

      _currentKeypair.onChange.listen((change) async {
        await clearPlus(change.m);
      });

      _currentLease.onChange.listen((change) async {
        if (change.now == null) {
          await reactToPlusLost(m, "current lease dropped");
        }
      });

      _currentGateway.onChange.listen((change) async {
        if (change.now == null) {
          await reactToPlusLost(m, "current gateway dropped");
        }
      });

      _bypassedPackages.onChange.listen((change) async {
        await _scheduler.addOrUpdate(Job("reconfigureVpnAfterBypassChange", change.m,
            before: DateTime.now().add(const Duration(seconds: 3)),
            callback: reconfigureVpnAfterBypassChange));
      });

      await _gateway.fetch(m);
      try {
        await _gateway.load(m);
      } on Exception catch (e) {
        log(m).w("current gateway unknown, setting to null");
        log(m).w("gateway returned: $e");
        // Gateway will be null, which triggers reactToPlusLost via onChange listener
      }

      if (_account.type == AccountType.plus) {
        await _lease.fetch(m);
      }

      _app.addOn(appStatusChanged, reactToAppStatus);
    });
  }

  newPlus(GatewayId id, Marker m) async {
    return await log(m).trace("newPlus", (m) async {
      try {
        await _app.reconfiguring(m);
        // No need to clear lease because backend will clear for the same key/acc
        await _lease.newLease(id, m);
        await switchPlus(true, m);
      } on TooManyLeasesException catch (_) {
        await _app.plusActivated(false, m);
        _modal.change(m, Modal.plusDeviceLimitReached);
      } catch (e) {
        await _app.plusActivated(false, m);
        await _stage.showModal(StageModal.plusVpnFailure, m);
        rethrow;
      }
    });
  }

  clearPlus(Marker m) async {
    return await log(m).trace("clearPlus", (m) async {
      await switchPlus(false, m);
      await _clearLease(m);
    });
  }

  switchPlus(bool active, Marker m) async {
    return await log(m).trace("switchPlus", (m) async {
      log(m).pair("active", active);
      try {
        _isSwitching = true;

        // Save the active flag
        await _plusEnabled.change(m, active);

        // Always VPN stop first
        await _vpn.turnVpnOff(m);

        if (active) {
          await _lease.fetch(m);
          final l = await _currentLease.now();
          final k = await _currentKeypair.now();
          final g = await _currentGateway.now();

          if (l == null || k == null || g == null) {
            throw Exception(
                "Missing lease (${l?.publicKey}), keypair (${k?.publicKey}) or gateway (${g?.publicKey})");
          }

          var b = await _bypassedPackages.now();
          b ??= <String>{};

          log(m).pair("bypassed apps", b);

          await _vpn.setVpnConfig(_assembleConfig(k, g, l, b), m);
          await _vpn.turnVpnOn(m);

          var requestAttempts = 5;
          while (requestAttempts-- > 0) {
            try {
              // A quick lease check to ensure connectivity
              await _lease.fetch(m, noRetry: true);
              requestAttempts = 0;
            } catch (_) {
              // Super lame but VPN service seems very brittle
              log(m).i("Retrying switching plus");
              await _vpn.turnVpnOff(m);
              await _vpn.turnVpnOn(m);
            }
          }
        }
      } on Exception catch (e) {
        await _plusEnabled.change(m, false);
        await _vpn.turnVpnOff(m);
        await _clearLease(m);
        await _app.plusActivated(false, m);
        await _stage.showModal(StageModal.plusVpnFailure, m);
        rethrow;
      } finally {
        _isSwitching = false;
      }
    });
  }

  VpnConfig _assembleConfig(
      Keypair keypair, Gateway gateway, Lease lease, Set<String> bypassedPackages) {
    return VpnConfig(
      devicePrivateKey: keypair.privateKey,
      deviceTag: _device.currentDeviceTag,
      gatewayPublicKey: gateway.publicKey,
      gatewayNiceName: gateway.niceName,
      gatewayIpv4: gateway.ipv4,
      gatewayIpv6: gateway.ipv6,
      gatewayPort: gateway.port.toString(),
      leaseVip4: lease.vip4,
      leaseVip6: lease.vip6,
      bypassedPackages: bypassedPackages,
    );
  }

  _clearLease(Marker m) async {
    final current = _currentLease.present;
    if (current != null) {
      await _lease.deleteLease(current, m);
    }
  }

  reactToAppPause(bool appActive, Marker m) async {
    return await log(m).trace("reactToAppPause", (m) async {
      final plusEnabled = await _plusEnabled.now();
      if (appActive && plusEnabled && !_vpnStatus.now.isActive()) {
        await switchPlus(true, m);
      } else if (!appActive && (plusEnabled || _vpnStatus.now.isActive())) {
        await _vpn.turnVpnOff(m);
      }
    });
  }

  reactToAppStatus(Marker m) async {
    final plusEnabled = await _plusEnabled.now();
    if (plusEnabled &&
        !_isSwitching &&
        _app.status == AppStatus.activatedCloud &&
        _vpnStatus.now == VpnStatus.deactivated) {
      // If VPN was on, but is not (for example after app restart), bring it up.
      return await log(m).trace("reactToAppStatusC1", (m) async {
        await switchPlus(true, m);
      });
    } else if (!plusEnabled && _app.status == AppStatus.activatedPlus) {
      // If the VPN is active (for example after app start), but we did not
      // expect it, try to sync the state.
      return await log(m).trace("reactToAppStatusC2", (m) async {
        await switchPlus(true, m);
      });
    } else if (plusEnabled &&
        _app.status == AppStatus.pausedPlus &&
        _vpnStatus.now == VpnStatus.deactivated) {
      // If app is paused with timer, VPN should be active, but is not (probably after app restart).
      return await log(m).trace("reactToAppStatusC3", (m) async {
        await switchPlus(true, m);
      });
    }
  }

  reactToPlusLost(Marker m, String reason) async {
    return await log(m).trace("reactToPlusLost", (m) async {
      log(m).w("Lost Plus, reason: $reason");
      final plusEnabled = await _plusEnabled.now();
      if (plusEnabled || _vpnStatus.now.isActive()) {
        await _plusEnabled.change(m, false);
        await _vpn.turnVpnOff(m);
        await _clearLease(m);
      }
    });
  }

  Future<bool> reconfigureVpnAfterBypassChange(Marker m) async {
    final plusEnabled = await _plusEnabled.now();
    if (!plusEnabled || _app.status != AppStatus.activatedPlus) return false;
    await switchPlus(true, m);
    return false;
  }
}
