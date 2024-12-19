import 'package:common/core/core.dart';
import 'package:common/platform/plus/keypair/keypair.dart';
import 'package:common/platform/plus/lease/json.dart';
import 'package:mobx/mobx.dart';

import '../../util/mobx.dart';
import '../account/account.dart';
import '../app/app.dart';
import '../device/device.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
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

abstract class PlusStoreBase with Store, Logging, Actor {
  late final _ops = Core.get<PlusOps>();
  late final _keypair = Core.get<PlusKeypairStore>();
  late final _gateway = Core.get<PlusGatewayStore>();
  late final _lease = Core.get<PlusLeaseStore>();
  late final _vpn = Core.get<PlusVpnStore>();
  late final _persistence = Core.get<Persistence>();
  late final _app = Core.get<AppStore>();
  late final _device = Core.get<DeviceStore>();
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();

  PlusStoreBase() {
    _app.addOn(appStatusChanged, reactToAppStatus);
    reactionOnStore((_) => plusEnabled, (plusEnabled) async {
      await _ops.doPlusEnabledChanged(plusEnabled);
    });
  }

  @override
  onRegister() {
    Core.register<PlusOps>(getOps());
    Core.register<PlusStore>(this as PlusStore);
  }

  @observable
  bool plusEnabled = false;

  @override
  Future<void> onStart(Marker m) async {
    return await log(m).trace("start", (m) async {
      // Assuming keypair already loaded
      await load(m);
      if (Core.act.isFamily) return;

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
      plusEnabled = await _persistence.load(m, _keySelected) == "1";
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
    await _persistence.save(m, _keySelected, plusEnabled ? "1" : "0");
  }
}
