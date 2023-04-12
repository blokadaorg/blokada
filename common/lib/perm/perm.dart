import 'package:mobx/mobx.dart';

import '../stage/stage.dart';
import '../util/di.dart';
import '../util/trace.dart';
import '../device/device.dart';
import 'channel.pg.dart';

part 'perm.g.dart';

class PermStore = PermStoreBase with _$PermStore;

abstract class PermStoreBase with Store, Traceable {
  @observable
  DeviceTag? privateDnsEnabled;

  @observable
  int privateDnsTagChangeCounter = 0;

  @observable
  bool notificationEnabled = false;

  @observable
  bool vpnEnabled = false;

  @action
  Future<void> setPrivateDnsEnabled(Trace parentTrace, DeviceTag tag) async {
    return await traceWith(parentTrace, "privateDnsEnabled", (trace) async {
      privateDnsEnabled = tag;
      trace.addAttribute("tag", tag);
    });
  }

  @action
  Future<void> setPrivateDnsDisabled(Trace parentTrace) async {
    return await traceWith(parentTrace, "privateDnsDisabled", (trace) async {
      privateDnsEnabled = null;
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
  Future<void> setVpnEnabled(Trace parentTrace, bool enabled) async {
    return await traceWith(parentTrace, "vpnEnabled", (trace) async {
      vpnEnabled = enabled;
      trace.addAttribute("enabled", enabled);
    });
  }

  bool isPrivateDnsEnabledFor(DeviceTag? tag) {
    return tag != null && privateDnsEnabled == tag;
  }
}

class PermBinder with Traceable {
  late final _store = di<PermStore>();
  late final _ops = di<PermOps>();
  late final _stage = di<StageStore>();
  late final _cloud = di<DeviceStore>();

  DeviceTag? _previousTag;

  PermBinder() {
    _onForeground();
    _onTagChange();
    _onTagCounterChange();
  }

  // Update device tag whenever set
  _onTagChange() {
    reaction((_) => _cloud.deviceTag, (tag) async {
      if (tag != null && (_previousTag == null || tag != _previousTag)) {
        await traceAs("onTagChange", (trace) async {
          _store.incrementPrivateDnsTagChangeCounter(trace);
          _previousTag = tag;
        });
      }
    });
  }

  // Will check the activation status on every foreground event
  _onForeground() {
    reaction((_) => _stage.isForeground, (isForeground) async {
      final tag = _cloud.deviceTag;
      if (tag != null && isForeground) {
        await traceAs("onForeground", (trace) async {
          await _recheckPerm(trace, tag);
        });
      }
    });
  }

  // Whenever device tag from backend changes, update the DNS profile in system
  // settings if possible. User is meant to activate it manually, but our app
  // can update it on iOS. Then, recheck the perms.
  _onTagCounterChange() {
    reaction((_) => _store.privateDnsTagChangeCounter, (tagCounter) async {
      await traceAs("onPrivateDnsTagCounterChange", (trace) async {
        trace.addAttribute("tagCounter", tagCounter);
        final tag = _cloud.deviceTag!;
        await _ops.doSetSetPrivateDnsEnabled(tag);
        await _recheckPerm(trace, tag);
      });
    });
  }

  _recheckPerm(Trace trace, DeviceTag tag) async {
    final isEnabled = await _ops.doPrivateDnsEnabled(tag);
    if (isEnabled) {
      await _store.setPrivateDnsEnabled(trace, tag);
    } else {
      await _store.setPrivateDnsDisabled(trace);
    }
  }
}

Future<void> init() async {
  di.registerSingleton<PermOps>(PermOps());
  di.registerSingleton<PermStore>(PermStore());
  PermBinder();
}
