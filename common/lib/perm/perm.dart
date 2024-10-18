import 'package:common/logger/logger.dart';
import 'package:common/perm/dnscheck.dart';
import 'package:mobx/mobx.dart';

import '../app/app.dart';
import '../device/device.dart';
import '../plus/plus.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'perm.g.dart';

class PermStore = PermStoreBase with _$PermStore;

abstract class PermStoreBase with Store, Logging, Dependable {
  late final _ops = dep<PermOps>();
  late final _app = dep<AppStore>();
  late final _device = dep<DeviceStore>();
  late final _plus = dep<PlusStore>();
  late final _stage = dep<StageStore>();
  late final _check = dep<PrivateDnsCheck>();

  PermStoreBase() {
    _stage.addOnValue(routeChanged, onRouteChanged);
  }

  @override
  attach(Act act) {
    _app.addOn(appStatusChanged, onAppStatusChanged);
    _device.addOn(deviceChanged, onDeviceChanged);

    depend<PermOps>(getOps(act));
    depend<PermStore>(this as PermStore);
  }

  @observable
  DeviceTag? privateDnsEnabledFor;

  @computed
  bool get isPrivateDnsEnabled {
    return _device.deviceTag != null &&
        privateDnsEnabledFor == _device.deviceTag;
  }

  @observable
  int privateDnsTagChangeCounter = 0;

  @observable
  bool notificationEnabled = false;

  @observable
  bool vpnEnabled = false;

  DeviceTag? _previousTag;
  String? _previousAlias;

  @action
  Future<void> setPrivateDnsEnabled(DeviceTag tag, Marker m) async {
    return await log(m).trace("privateDnsEnabled", (m) async {
      log(m).pair("tag", tag);

      if (tag != privateDnsEnabledFor) {
        privateDnsEnabledFor = tag;
        await _app.cloudPermEnabled(tag == _device.deviceTag, m);
      }
    });
  }

  @action
  Future<void> setPrivateDnsDisabled(Marker m) async {
    return await log(m).trace("privateDnsDisabled", (m) async {
      if (privateDnsEnabledFor != null) {
        privateDnsEnabledFor = null;
        await _app.cloudPermEnabled(false, m);
      }
    });
  }

  @action
  Future<void> incrementPrivateDnsTagChangeCounter(Marker m) async {
    return await log(m).trace("incrementPrivateDnsTagChangeCounter", (m) async {
      privateDnsTagChangeCounter += 1;
    });
  }

  @action
  Future<void> setNotificationEnabled(bool enabled, Marker m) async {
    return await log(m).trace("notificationEnabled", (m) async {
      if (enabled != notificationEnabled) {
        notificationEnabled = enabled;
        log(m).pair("enabled", enabled);
      }
    });
  }

  @action
  Future<void> setVpnPermEnabled(bool enabled, Marker m) async {
    return await log(m).trace("setVpnPermEnabled", (m) async {
      if (enabled != vpnEnabled) {
        log(m).pair("enabled", enabled);
        vpnEnabled = enabled;
        if (!enabled) {
          if (!act.isFamily()) await _plus.reactToPlusLost(m);
          await _app.plusActivated(false, m);
        }
      }
    });
  }

  // Whenever device tag from backend changes, update the DNS profile in system
  // settings if possible. User is meant to activate it manually, but our app
  // can update it on iOS. Then, recheck the perms.
  @action
  Future<void> syncPermsAfterTagChange(String tag, Marker m) async {
    return await log(m).trace("syncPermsAfterTagChange", (m) async {
      if (_previousTag == null ||
          tag != _previousTag ||
          _previousAlias == null ||
          _previousAlias != _device.deviceAlias) {
        incrementPrivateDnsTagChangeCounter;
        _previousTag = tag;
        _previousAlias = _device.deviceAlias;

        if (!act.isFamily()) {
          await _ops.doSetPrivateDnsEnabled(tag, _device.deviceAlias);
          await _recheckDnsPerm(tag, m);
        }

        await _recheckVpnPerm(m);
      }
    });
  }

  @action
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

  @action
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!(route.isBecameForeground() || route.modal == StageModal.perms)) {
      return;
    }

    return await log(m).trace("checkPermsOnFg", (m) async {
      await syncPerms(m);
    });
  }

  @action
  Future<void> onAppStatusChanged(Marker m) async {
    return await log(m).trace("onAppStatusChanged", (m) async {
      if (_app.status.isInactive()) {
        await syncPerms(m);
      }
    });
  }

  @action
  Future<void> onDeviceChanged(Marker m) async {
    return await log(m).trace("onDeviceChanged", (m) async {
      final tag = _device.deviceTag;
      if (tag != null) await syncPermsAfterTagChange(tag, m);
    });
  }

  bool isPrivateDnsEnabledFor(DeviceTag? tag) {
    return tag != null && privateDnsEnabledFor == tag;
  }

  _recheckDnsPerm(DeviceTag tag, Marker m) async {
    final current = await _ops.getPrivateDnsSetting();
    final isEnabled =
        _check.isCorrect(m, current, _device.deviceTag!, _device.deviceAlias);

    if (isEnabled) {
      await setPrivateDnsEnabled(tag, m);
    } else {
      await setPrivateDnsDisabled(m);
    }
  }

  _recheckVpnPerm(Marker m) async {
    final isEnabled = await _ops.doVpnEnabled();
    await setVpnPermEnabled(isEnabled, m);
  }
}
