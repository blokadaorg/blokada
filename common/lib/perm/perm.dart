import 'package:mobx/mobx.dart';

import '../app/app.dart';
import '../util/di.dart';
import '../util/trace.dart';
import '../device/device.dart';
import 'channel.pg.dart';

part 'perm.g.dart';

class PermStore = PermStoreBase with _$PermStore;

abstract class PermStoreBase with Store, Traceable, Dependable {
  late final _ops = di<PermOps>();
  late final _app = dep<AppStore>();
  late final _device = dep<DeviceStore>();

  PermStoreBase() {}

  @override
  attach() {
    depend<PermOps>(PermOps());
    depend<PermStore>(this as PermStore);
  }

  @observable
  DeviceTag? privateDnsEnabled;

  @observable
  int privateDnsTagChangeCounter = 0;

  @observable
  bool notificationEnabled = false;

  @observable
  bool vpnEnabled = false;

  DeviceTag? _previousTag;

  @action
  Future<void> setPrivateDnsEnabled(Trace parentTrace, DeviceTag tag) async {
    return await traceWith(parentTrace, "privateDnsEnabled", (trace) async {
      trace.addAttribute("tag", tag);

      privateDnsEnabled = tag;
      await _app.cloudPermEnabled(trace, tag == _device.deviceTag);
    });
  }

  @action
  Future<void> setPrivateDnsDisabled(Trace parentTrace) async {
    return await traceWith(parentTrace, "privateDnsDisabled", (trace) async {
      privateDnsEnabled = null;
      await _app.cloudPermEnabled(trace, false);
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
      notificationEnabled = enabled;
      trace.addAttribute("enabled", enabled);
    });
  }

  @action
  Future<void> setVpnPermEnabled(Trace parentTrace, bool enabled) async {
    return await traceWith(parentTrace, "setVpnPermEnabled", (trace) async {
      vpnEnabled = enabled;
      trace.addAttribute("enabled", enabled);
    });
  }

  // Whenever device tag from backend changes, update the DNS profile in system
  // settings if possible. User is meant to activate it manually, but our app
  // can update it on iOS. Then, recheck the perms.
  @action
  Future<void> syncDeviceTag(Trace parentTrace, String tag) async {
    return await traceWith(parentTrace, "syncDeviceTag", (trace) async {
      if (_previousTag == null || tag != _previousTag) {
        incrementPrivateDnsTagChangeCounter(trace);
        _previousTag = tag;

        await _ops.doSetSetPrivateDnsEnabled(tag);
        await _recheckDnsPerm(trace, tag);
        await _recheckVpnPerm(trace);
      }
    });
  }

  @action
  Future<void> syncForeground(Trace parentTrace, bool isForeground) async {
    // TODO: check all perms on foreground
    return await traceWith(parentTrace, "syncForeground", (trace) async {
      final tag = _device.deviceTag;
      if (isForeground && tag != null) {
        await _recheckDnsPerm(trace, tag);
        await _recheckVpnPerm(trace);
      }
    });
  }

  bool isPrivateDnsEnabledFor(DeviceTag? tag) {
    return tag != null && privateDnsEnabled == tag;
  }

  _recheckDnsPerm(Trace trace, DeviceTag tag) async {
    final isEnabled = await _ops.doPrivateDnsEnabled(tag);
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
