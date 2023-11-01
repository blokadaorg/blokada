import 'package:mobx/mobx.dart';

import '../app/app.dart';
import '../plus/plus.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/trace.dart';
import '../device/device.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'perm.g.dart';

class PermStore = PermStoreBase with _$PermStore;

abstract class PermStoreBase with Store, Traceable, Dependable {
  late final _ops = dep<PermOps>();
  late final _app = dep<AppStore>();
  late final _device = dep<DeviceStore>();
  late final _plus = dep<PlusStore>();
  late final _stage = dep<StageStore>();

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
  DeviceTag? privateDnsEnabled;

  // Used for when we want to skip our own dns and just forward it.
  // This is only for Family, for when device is unlocked.
  @observable
  bool isForwardDns = false;

  @observable
  int privateDnsTagChangeCounter = 0;

  @observable
  bool notificationEnabled = false;

  @observable
  bool vpnEnabled = false;

  DeviceTag? _previousTag;
  String? _previousAlias;

  @action
  Future<void> setPrivateDnsEnabled(Trace parentTrace, DeviceTag tag) async {
    return await traceWith(parentTrace, "privateDnsEnabled", (trace) async {
      trace.addAttribute("tag", tag);

      if (tag != privateDnsEnabled) {
        privateDnsEnabled = tag;
        await _app.cloudPermEnabled(trace, tag == _device.deviceTag);
      }
    });
  }

  @action
  Future<void> setPrivateDnsDisabled(Trace parentTrace) async {
    return await traceWith(parentTrace, "privateDnsDisabled", (trace) async {
      if (privateDnsEnabled != null) {
        privateDnsEnabled = null;
        await _app.cloudPermEnabled(trace, false);
      }
    });
  }

  @action
  Future<void> incrementPrivateDnsTagChangeCounter(Trace parentTrace) async {
    return await traceWith(parentTrace, "incrementPrivateDnsTagChangeCounter",
        (trace) async {
      privateDnsTagChangeCounter += 1;
    });
  }

  @action
  Future<void> setNotificationEnabled(Trace parentTrace, bool enabled) async {
    return await traceWith(parentTrace, "notificationEnabled", (trace) async {
      if (enabled != notificationEnabled) {
        notificationEnabled = enabled;
        trace.addAttribute("enabled", enabled);
      }
    });
  }

  @action
  Future<void> setVpnPermEnabled(Trace parentTrace, bool enabled) async {
    return await traceWith(parentTrace, "setVpnPermEnabled", (trace) async {
      if (enabled != vpnEnabled) {
        trace.addAttribute("enabled", enabled);
        vpnEnabled = enabled;
        if (!enabled) {
          await _plus.reactToPlusLost(trace);
          await _app.plusActivated(trace, false);
        }
      }
    });
  }

  // Whenever device tag from backend changes, update the DNS profile in system
  // settings if possible. User is meant to activate it manually, but our app
  // can update it on iOS. Then, recheck the perms.
  @action
  Future<void> syncPermsAfterTagChange(Trace parentTrace, String tag) async {
    return await traceWith(parentTrace, "syncPermsAfterTagChange",
        (trace) async {
      if (_previousTag == null ||
          tag != _previousTag ||
          _previousAlias == null ||
          _previousAlias != _device.deviceAlias) {
        incrementPrivateDnsTagChangeCounter(trace);
        _previousTag = tag;
        _previousAlias = _device.deviceAlias;

        if (isForwardDns) {
          await _ops.doSetSetPrivateDnsForward();
        } else {
          await _ops.doSetSetPrivateDnsEnabled(tag, _device.deviceAlias);
        }

        await _recheckDnsPerm(trace, tag);
        await _recheckVpnPerm(trace);
      }
    });
  }

  @action
  Future<void> setForwardDns(Trace parentTrace, bool forward) async {
    return await traceWith(parentTrace, "setForwardDns", (trace) async {
      trace.addAttribute("forward", forward);
      isForwardDns = forward;
      final tag = _previousTag;
      _previousTag = null;
      if (tag != null) {
        await syncPermsAfterTagChange(trace, tag);
      } else if (forward) {
        await _ops.doSetSetPrivateDnsForward();
      }
    });
  }

  @action
  Future<void> syncPerms(Trace parentTrace) async {
    // TODO: check all perms on foreground
    return await traceWith(parentTrace, "syncPerms", (trace) async {
      final tag = _device.deviceTag;
      if (tag != null) {
        await _recheckDnsPerm(trace, tag);
        await _recheckVpnPerm(trace);
      }
    });
  }

  @action
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (!route.isBecameForeground() && route.modal != StageModal.perms) return;

    return await traceWith(parentTrace, "checkPermsOnFg", (trace) async {
      await syncPerms(trace);
    });
  }

  @action
  Future<void> onAppStatusChanged(Trace parentTrace) async {
    return await traceWith(parentTrace, "onAppStatusChanged", (trace) async {
      if (_app.status.isInactive()) {
        await syncPerms(trace);
      }
    });
  }

  @action
  Future<void> onDeviceChanged(Trace parentTrace) async {
    return await traceWith(parentTrace, "onDeviceChanged", (trace) async {
      final tag = _device.deviceTag;
      if (tag != null) await syncPermsAfterTagChange(trace, tag);
    });
  }

  bool isPrivateDnsEnabledFor(DeviceTag? tag) {
    return tag != null && privateDnsEnabled == tag;
  }

  _recheckDnsPerm(Trace trace, DeviceTag tag) async {
    final isEnabled = await _ops.doPrivateDnsEnabled(tag, _device.deviceAlias);
    if (isEnabled) {
      await setPrivateDnsEnabled(trace, tag);
    } else {
      await setPrivateDnsDisabled(trace);
    }
  }

  _recheckVpnPerm(Trace trace) async {
    final isEnabled = await _ops.doVpnEnabled();
    await setVpnPermEnabled(trace, isEnabled);
  }
}
