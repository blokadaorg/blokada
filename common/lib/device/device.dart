import 'package:mobx/mobx.dart';

import '../env/env.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'device.g.dart';

typedef DeviceTag = String;
typedef DeviceRetention = String;

extension DeviceRetentionExt on DeviceRetention {
  bool isEnabled() {
    return isNotEmpty;
  }
}

class DeviceStore = DeviceStoreBase with _$DeviceStore;

abstract class DeviceStoreBase with Store, Traceable {
  late final _api = di<DeviceJson>();

  @observable
  bool? cloudEnabled;

  @observable
  DeviceTag? deviceTag;

  @observable
  List<String>? lists;

  @observable
  DeviceRetention? retention;

  @action
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      final device = await _api.getDevice(trace);
      cloudEnabled = !device.paused;
      deviceTag = device.deviceTag;
      lists = device.lists;
      retention = device.retention;
      trace.addAttribute("tag", deviceTag);
    });
  }

  @action
  Future<void> setCloudEnabled(Trace parentTrace, bool enabled) async {
    return await traceWith(parentTrace, "setCloudEnabled", (trace) async {
      await _api.putDevice(trace, paused: !enabled);
      await fetch(trace);
    });
  }

  @action
  Future<void> setRetention(
      Trace parentTrace, DeviceRetention retention) async {
    return await traceWith(parentTrace, "setRetention", (trace) async {
      trace.addAttribute("retention", retention);
      await _api.putDevice(trace, retention: retention);
      await fetch(trace);
    });
  }

  @action
  Future<void> setLists(Trace parentTrace, List<String> lists) async {
    return await traceWith(parentTrace, "setLists", (trace) async {
      trace.addAttribute("lists", lists);
      await _api.putDevice(trace, lists: lists);
      await fetch(trace);
    });
  }
}

class DeviceBinder extends DeviceEvents with Traceable {
  late final _store = di<DeviceStore>();
  late final _ops = di<DeviceOps>();
  late final _stage = di<StageStore>();
  late final _env = di<EnvStore>();

  DeviceBinder() {
    DeviceEvents.setup(this);
    _init();
  }

  DeviceBinder.forTesting() {
    _init();
  }

  _init() {
    _onCloudEnabled();
    _onRetention();
    _onDeviceTag();
    _onTabChange();
    _onAccountIdChange();
  }

  @override
  Future<void> onEnableCloud(bool enable) async {
    await traceAs("onEnableCloud", (trace) async {
      await _store.setCloudEnabled(trace, enable);
    });
  }

  @override
  Future<void> onSetRetention(String retention) async {
    await traceAs("onSetRetention", (trace) async {
      await _store.setRetention(trace, retention);
    });
  }

  // Report cloud enabled state changes to the channel
  _onCloudEnabled() {
    reaction((_) => _store.cloudEnabled, (enabled) async {
      await traceAs("onCloudEnabled", (trace) async {
        _ops.doCloudEnabled(enabled!);
      });
    });
  }

  _onRetention() {
    reaction((_) => _store.retention, (retention) async {
      if (retention != null) {
        await traceAs("onRetention", (trace) async {
          _ops.doRetentionChanged(retention);
        });
      }
    });
  }

  _onDeviceTag() {
    reaction((_) => _store.deviceTag, (tag) async {
      if (tag != null) {
        await traceAs("onDeviceTag", (trace) async {
          _ops.doDeviceTagChanged(tag);
        });
      }
    });
  }

  // Will recheck device info on each tab change.
  // This struct contains something important for each tab.
  _onTabChange() {
    reaction((_) => _stage.activeTab, (tab) async {
      await traceAs("onTabChange", (trace) async {
        // TODO: this is too often
        await _store.fetch(trace);
      });
    });
  }

  // Whenever account ID is changed, device tag will change, among other things.
  _onAccountIdChange() {
    reaction((_) => _env.accountIdChanges, (counter) async {
      await traceAs("onAccountIdChange", (trace) async {
        trace.addAttribute("accountIdCounter", counter);
        await _store.fetch(trace);
      });
    });
  }
}

Future<void> init() async {
  di.registerSingleton<DeviceJson>(DeviceJson());
  di.registerSingleton<DeviceOps>(DeviceOps());
  di.registerSingleton<DeviceStore>(DeviceStore());
  DeviceBinder();
}
