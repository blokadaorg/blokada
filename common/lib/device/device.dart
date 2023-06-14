import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../account/channel.pg.dart';
import '../stage/stage.dart';
import '../util/config.dart';
import '../util/cooldown.dart';
import '../util/di.dart';
import '../util/emitter.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'device.g.dart';

final deviceChanged = EmitterEvent<JsonDevice>();

typedef DeviceTag = String;
typedef DeviceRetention = String;

extension DeviceRetentionExt on DeviceRetention {
  bool isEnabled() {
    return isNotEmpty;
  }
}

class DeviceStore = DeviceStoreBase with _$DeviceStore;

abstract class DeviceStoreBase
    with Store, Traceable, Dependable, Cooldown, Emitter {
  late final _ops = dep<DeviceOps>();
  late final _api = dep<DeviceJson>();
  late final _stage = dep<StageStore>();
  late final _account = dep<AccountStore>();

  DeviceStoreBase() {
    willAcceptOn([deviceChanged]);

    _stage.addOnValue(routeChanged, onRouteChanged);
    _account.addOn(accountChanged, onAccountChanged);
    _account.addOn(accountIdChanged, fetch);

    reactionOnStore((_) => cloudEnabled, (enabled) async {
      _ops.doCloudEnabled(enabled!);
    });

    reactionOnStore((_) => retention, (retention) async {
      if (retention != null) {
        _ops.doRetentionChanged(retention);
      }
    });

    reactionOnStore((_) => deviceTag, (tag) async {
      if (tag != null) {
        _ops.doDeviceTagChanged(tag);
      }
    });
  }

  @override
  attach(Act act) {
    depend<DeviceOps>(getOps(act));
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

  @computed
  String get currentDeviceTag {
    final tag = deviceTag;
    if (tag == null) {
      throw Exception("No device tag set yet");
    }
    return tag;
  }

  @action
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      trace.addAttribute("tag", deviceTag);

      final device = await _api.getDevice(trace);
      cloudEnabled = !device.paused;
      deviceTag = device.deviceTag;
      lists = device.lists;
      retention = device.retention;

      await emit(deviceChanged, trace, device);
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
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (!route.isForeground()) return;
    if (!route.isMainRoute()) return;
    if (!isCooledDown(cfg.deviceRefreshCooldown)) return;

    return await traceWith(parentTrace, "fetchDevice", (trace) async {
      await fetch(trace);
    });
  }

  @action
  Future<void> onAccountChanged(Trace parentTrace) async {
    return await traceWith(parentTrace, "onAccountChanged", (trace) async {
      await fetch(trace);
    });
  }
}
