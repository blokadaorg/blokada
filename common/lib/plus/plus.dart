import 'package:common/plus/keypair/keypair.dart';
import 'package:common/plus/lease/json.dart';
import 'package:mobx/mobx.dart';

import '../app/app.dart';
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

abstract class PlusStoreBase with Store, Traceable, Dependable {
  late final _ops = dep<PlusOps>();
  late final _keypair = dep<PlusKeypairStore>();
  late final _gateway = dep<PlusGatewayStore>();
  late final _lease = dep<PlusLeaseStore>();
  late final _vpn = dep<PlusVpnStore>();
  late final _persistence = dep<PersistenceService>();
  late final _app = dep<AppStore>();
  late final _device = dep<DeviceStore>();
  late final _stage = dep<StageStore>();

  PlusStoreBase() {
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

  @action
  Future<void> load(Trace parentTrace) async {
    return await traceWith(parentTrace, "load", (trace) async {
      plusEnabled = await _persistence.load(trace, _keySelected) == "1";
    });
  }

  @action
  Future<void> newPlus(Trace parentTrace, GatewayId id) async {
    return await traceWith(parentTrace, "newPlus", (trace) async {
      try {
        await _app.reconfiguring(trace);
        // No need to clear lease because backend will clear for the same key/acc
        await _lease.newLease(trace, id);
        await switchPlus(trace, true);
      } on TooManyLeasesException catch (_) {
        await _app.plusActivated(trace, false);
        await _stage.showModal(trace, StageModal.plusTooManyLeases);
      } catch (_) {
        await _app.plusActivated(trace, false);
        await _stage.showModal(trace, StageModal.plusVpnFailure);
        rethrow;
      }
    });
  }

  @action
  Future<void> clearPlus(Trace parentTrace) async {
    return await traceWith(parentTrace, "clearPlus", (trace) async {
      await switchPlus(trace, false);
      _clearLease(trace);
    });
  }

  @action
  Future<void> switchPlus(Trace parentTrace, bool active) async {
    return await traceWith(parentTrace, "switchPlus", (trace) async {
      trace.addAttribute("active", active);
      try {
        // Save the active flag
        plusEnabled = active;
        await _saveFlag(trace);

        // Always VPN stop first
        await _vpn.turnVpnOff(trace);

        if (active) {
          final l = _lease.currentLease;
          final k = _keypair.currentKeypair;
          final g = _gateway.currentGateway;

          if (l == null || k == null || g == null) {
            throw Exception("Missing lease, keypair or gateway");
          }

          await _vpn.setVpnConfig(trace, _assembleConfig(k, g, l));
          await _vpn.turnVpnOn(trace);
          await _lease.fetch(trace);
        }
      } on Exception catch (_) {
        plusEnabled = false;
        await _saveFlag(trace);
        _clearLease(trace);
        await _stage.showModal(trace, StageModal.plusVpnFailure);
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

  _clearLease(Trace trace) async {
    final current = _lease.currentLease;
    if (current != null) {
      await _lease.deleteLease(trace, current);
    }
  }

  @action
  Future<void> reactToAppPause(Trace parentTrace, bool appActive) async {
    return await traceWith(parentTrace, "reactToAppStatus", (trace) async {
      if (appActive && plusEnabled && !_vpn.actualStatus.isActive()) {
        await _vpn.turnVpnOn(trace);
        await _lease.fetch(trace);
      } else if (!appActive && (plusEnabled || _vpn.actualStatus.isActive())) {
        await _vpn.turnVpnOff(trace);
      }
    });
  }

  @action
  Future<void> reactToPermLost(Trace parentTrace) async {
    return await traceWith(parentTrace, "reactToPermLost", (trace) async {
      if (plusEnabled || _vpn.actualStatus.isActive()) {
        plusEnabled = false;
        _clearLease(trace);
        await _vpn.turnVpnOff(trace);
      }
    });
  }

  _saveFlag(Trace trace) async {
    await _persistence.saveString(trace, _keySelected, plusEnabled ? "1" : "0");
  }
}
