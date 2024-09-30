import 'package:common/logger/logger.dart';
import 'package:common/plus/keypair/keypair.dart';
import 'package:common/plus/lease/json.dart';
import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../app/app.dart';
import '../app/channel.pg.dart';
import '../device/device.dart';
import '../persistence/persistence.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'gateway/channel.pg.dart';
import 'gateway/gateway.dart';
import 'keypair/channel.pg.dart';
import 'lease/channel.pg.dart';
import 'lease/lease.dart';
import 'vpn/channel.pg.dart';
import 'vpn/vpn.dart';

part 'plus.g.dart';

const String _keySelected = "plus:active";

class PlusStore = PlusStoreBase with _$PlusStore;

abstract class PlusStoreBase with Store, Logging, Dependable, Startable {
  late final _ops = dep<PlusOps>();
  late final _keypair = dep<PlusKeypairStore>();
  late final _gateway = dep<PlusGatewayStore>();
  late final _lease = dep<PlusLeaseStore>();
  late final _vpn = dep<PlusVpnStore>();
  late final _persistence = dep<PersistenceService>();
  late final _app = dep<AppStore>();
  late final _device = dep<DeviceStore>();
  late final _stage = dep<StageStore>();
  late final _account = dep<AccountStore>();

  PlusStoreBase() {
    _app.addOn(appStatusChanged, reactToAppStatus);
    reactionOnStore((_) => plusEnabled, (plusEnabled) async {
      await _ops.doPlusEnabledChanged(plusEnabled);
    });
  }

  @override
  attach(Act act) {
    depend<PlusOps>(getOps(act));
    depend<PlusStore>(this as PlusStore);
  }

  @observable
  bool plusEnabled = false;

  @override
  @action
  Future<void> start(Marker m) async {
    return await log(m).trace("start", (m) async {
      // Assuming keypair already loaded
      await load(m);
      if (act.isFamily()) return;

      await _gateway.fetch(m);
      await _gateway.load(m);

      if (_account.type == AccountType.plus) {
        await _lease.fetch(m);
      }
    });
  }

  @action
  Future<void> load(Marker m) async {
    return await log(m).trace("load", (m) async {
      plusEnabled = await _persistence.load(_keySelected, m) == "1";
    });
  }

  @action
  Future<void> newPlus(GatewayId id, Marker m) async {
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

  @action
  Future<void> clearPlus(Marker m) async {
    return await log(m).trace("clearPlus", (m) async {
      await switchPlus(false, m);
      _clearLease(m);
    });
  }

  @action
  Future<void> switchPlus(bool active, Marker m) async {
    return await log(m).trace("switchPlus", (m) async {
      log(m).pair("active", active);
      try {
        // Save the active flag
        plusEnabled = active;
        await _saveFlag(m);

        // Always VPN stop first
        await _vpn.turnVpnOff(m);

        if (active) {
          final l = _lease.currentLease;
          final k = _keypair.currentKeypair;
          final g = _gateway.currentGateway;

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
        plusEnabled = false;
        await _vpn.turnVpnOff(m);
        await _saveFlag(m);
        _clearLease(m);
        await _app.plusActivated(false, m);
        await _stage.showModal(StageModal.plusVpnFailure, m);
        rethrow;
      }
    });
  }

  VpnConfig _assembleConfig(PlusKeypair keypair, Gateway gateway, Lease lease) {
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
    final current = _lease.currentLease;
    if (current != null) {
      await _lease.deleteLease(current, m);
    }
  }

  @action
  Future<void> reactToAppPause(bool appActive, Marker m) async {
    return await log(m).trace("reactToAppPause", (m) async {
      if (appActive && plusEnabled && !_vpn.actualStatus.isActive()) {
        await switchPlus(true, m);
      } else if (!appActive && (plusEnabled || _vpn.actualStatus.isActive())) {
        await _vpn.turnVpnOff(m);
      }
    });
  }

  @action
  Future<void> reactToAppStatus(Marker m) async {
    if (plusEnabled &&
        _app.status == AppStatus.activatedCloud &&
        _vpn.actualStatus == VpnStatus.deactivated) {
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

  @action
  Future<void> reactToPlusLost(Marker m) async {
    return await log(m).trace("reactToPlusLost", (m) async {
      if (plusEnabled || _vpn.actualStatus.isActive()) {
        plusEnabled = false;
        await _vpn.turnVpnOff(m);
        _clearLease(m);
      }
    });
  }

  _saveFlag(Marker m) async {
    await _persistence.saveString(_keySelected, plusEnabled ? "1" : "0", m);
  }
}
