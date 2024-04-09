import 'package:mobx/mobx.dart';
import 'package:unique_names_generator/unique_names_generator.dart' as names;

import '../account/account.dart';
import '../env/env.dart';
import '../persistence/persistence.dart';
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

final deviceChanged = EmitterEvent<DeviceTag>();

typedef DeviceTag = String;
typedef DeviceRetention = String;

extension DeviceRetentionExt on DeviceRetention {
  bool isEnabled() {
    return isNotEmpty;
  }
}

const String _keyAlias = "device:alias";
const String _keyTag = "device:tag";

class DeviceStore = DeviceStoreBase with _$DeviceStore;

abstract class DeviceStoreBase
    with Store, Traceable, Dependable, Startable, Cooldown, Emitter {
  late final _ops = dep<DeviceOps>();
  late final _api = dep<DeviceJson>();
  late final _stage = dep<StageStore>();
  late final _account = dep<AccountStore>();
  late final _persistence = dep<PersistenceService>();
  late final _env = dep<EnvStore>();

  late final _names = names.UniqueNamesGenerator(
    config: names.Config(
      length: 1,
      seperator: " ",
      style: names.Style.capital,
      dictionaries: [names.animals],
    ),
  );

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

    reactionOnStore((_) => deviceAlias, (alias) async {
      // Lazy way to provide UI with generated names to use
      final names = List.generate(10, (_) => _names.generate());
      await _ops.doNameProposalsChanged(names);

      if (alias.isNotEmpty) {
        _ops.doDeviceAliasChanged(alias);
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

  @observable
  String deviceAlias = "";

  @computed
  String get currentDeviceTag {
    final tag = deviceTag;
    if (tag == null) {
      throw Exception("No device tag set yet");
    }
    return tag;
  }

  @override
  @action
  Future<void> start(Trace parentTrace) async {
    return await traceWith(parentTrace, "start", (trace) async {
      await load(trace);
      await setDeviceName(trace, _env.deviceName);
    });
  }

  @action
  Future<void> load(Trace parentTrace) async {
    return await traceWith(parentTrace, "load", (trace) async {
      deviceAlias = await _persistence.load(trace, _keyAlias) ?? "";
    });
  }

  @action
  Future<void> fetch(Trace parentTrace) async {
    if (act.isFamily()) return;
    return await traceWith(parentTrace, "fetch", (trace) async {
      trace.addAttribute("tag", deviceTag);

      final device = await _api.getDevice(trace);
      cloudEnabled = !device.paused;
      lists = device.lists;
      retention = device.retention;

      await emit(deviceChanged, trace, deviceTag!);
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
  Future<void> setDeviceName(Trace parentTrace, String? deviceName) async {
    // Simple handling of OG flavor (no generated device names)
    // TODO: refactor
    if (!act.isFamily()) {
      deviceAlias = deviceName!;
      return;
    }
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
