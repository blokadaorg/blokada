import 'package:mobx/mobx.dart';

import '../event.dart';
import '../stage/stage.dart';
import '../util/config.dart';
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

abstract class DeviceStoreBase with Store, Traceable, Dependable {
  late final _ops = di<DeviceOps>();
  late final _api = di<DeviceJson>();
  late final _event = di<EventBus>();
  late final _stage = di<StageStore>();

  DeviceStoreBase() {
    reaction((_) => cloudEnabled, (enabled) async {
      _ops.doCloudEnabled(enabled!);
    });

    reaction((_) => retention, (retention) async {
      if (retention != null) {
        _ops.doRetentionChanged(retention);
      }
    });

    reaction((_) => deviceTag, (tag) async {
      if (tag != null) {
        _ops.doDeviceTagChanged(tag);
      }
    });
  }

  @override
  attach() {
    depend<DeviceOps>(DeviceOps());
    depend<DeviceJson>(DeviceJson());
    depend<DeviceStore>(this as DeviceStore);
  }

  @observable
  bool? cloudEnabled;

  @observable
  DeviceTag? deviceTag;

  @observable
  List<String>? lists;

  @observable
  DeviceRetention? retention;

  @observable
  DateTime lastRefresh = DateTime(0);

  String? _previousAccountId;

  @action
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      trace.addAttribute("tag", deviceTag);

      final device = await _api.getDevice(trace);
      cloudEnabled = !device.paused;
      deviceTag = device.deviceTag;
      lists = device.lists;
      retention = device.retention;

      await _event.onEvent(trace, CommonEvent.deviceConfigChanged);
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

  @action
  Future<void> maybeRefreshDevice(Trace parentTrace,
      {bool force = false}) async {
    return await traceWith(parentTrace, "maybeRefreshDevice", (trace) async {
      if (!_stage.isForeground) {
        return;
      }

      // Don't refresh on deep navigation
      if (!force && _stage.route.payload != null) {
        return;
      }

      final now = DateTime.now();
      if (force ||
          now.difference(lastRefresh).compareTo(cfg.deviceRefreshCooldown) >
              0) {
        await fetch(trace);
        lastRefresh = now;
        trace.addEvent("refreshed");
      }
    });
  }
}
