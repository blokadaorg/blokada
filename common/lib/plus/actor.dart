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

  late final _app = Core.get<AppStore>();
  late final _device = Core.get<DeviceStore>();
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();

  @override
  onCreate(Marker m) async {
    await _plusEnabled.fetch(m);
  }

  @override
  onStart(Marker m) async {
    return await log(m).trace("start", (m) async {
      _app.addOn(appStatusChanged, reactToAppStatus);

      _plusEnabled.onChange.listen((change) async {
        await _channel.doPlusEnabledChanged(change.now);
      });

      _currentKeypair.onChange.listen((change) async {
        await clearPlus(change.m);
      });

      _currentLease.onChange.listen((change) async {
        if (change.now == null) {
          await log(change.m).trace("currentLeaseDropped", (m) async {
            await reactToPlusLost(m);
          });
        }
      });

      _currentGateway.onChange.listen((change) async {
        if (change.now == null) {
          await log(change.m).trace("currentGatewayDropped", (m) async {
            await reactToPlusLost(m);
          });
        }
      });

      await _gateway.fetch(m);
      await _gateway.load(m);

      if (_account.type == AccountType.plus) {
        await _lease.fetch(m);
      }
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
        await _stage.showModal(StageModal.plusTooManyLeases, m);
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
        // Save the active flag
        await _plusEnabled.change(m, active);

        // Always VPN stop first
        await _vpn.turnVpnOff(m);

        if (active) {
          final l = _currentLease.present;
          final k = _currentKeypair.present;
          final g = _currentGateway.present;

          if (l == null || k == null || g == null) {
            throw Exception("Missing lease, keypair or gateway");
          }

          await _vpn.setVpnConfig(_assembleConfig(k, g, l), m);
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
      }
    });
  }

  VpnConfig _assembleConfig(Keypair keypair, Gateway gateway, Lease lease) {
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
    }
  }

  reactToPlusLost(Marker m) async {
    return await log(m).trace("reactToPlusLost", (m) async {
      final plusEnabled = await _plusEnabled.now();
      if (plusEnabled || _vpnStatus.now.isActive()) {
        await _plusEnabled.change(m, false);
        await _vpn.turnVpnOff(m);
        await _clearLease(m);
      }
    });
  }
}
