import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';
import 'package:unique_names_generator/unique_names_generator.dart' as names;

import '../../util/cooldown.dart';
import '../../util/mobx.dart';
import '../account/account.dart';
import '../env/env.dart';
import '../persistence/persistence.dart';
import '../stage/stage.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'device.g.dart';

final deviceChanged = EmitterEvent<DeviceTag>("deviceChanged");

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
    with Store, Logging, Dependable, Startable, Cooldown, Emitter {
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
  Future<void> start(Marker m) async {
    return await log(m).trace("start", (m) async {
      await load(m);
      await setDeviceName(_env.deviceName, m);
    });
  }

  @action
  Future<void> load(Marker m) async {
    return await log(m).trace("load", (m) async {
      deviceAlias = await _persistence.load(_keyAlias, m) ?? "";
    });
  }

  @action
  Future<void> fetch(Marker m) async {
    if (act.isFamily()) return;

    return await log(m).trace("fetch", (m) async {
      log(m).pair("tag", deviceTag);

      final device = await _api.getDevice(m);
      cloudEnabled = !device.paused;
      lists = device.lists;
      retention = device.retention;
      deviceTag = device.deviceTag;

      await emit(deviceChanged, deviceTag!, m);
    });
  }

  @action
  Future<void> setCloudEnabled(bool enabled, Marker m) async {
    return await log(m).trace("setCloudEnabled", (m) async {
      await _api.putDevice(m, paused: !enabled);
      await fetch(m);
    });
  }

  @action
  Future<void> setRetention(DeviceRetention retention, Marker m) async {
    return await log(m).trace("setRetention", (m) async {
      log(m).pair("retention", retention);
      await _api.putDevice(m, retention: retention);
      await fetch(m);
    });
  }

  @action
  Future<void> setLists(List<String> lists, Marker m) async {
    return await log(m).trace("setLists", (m) async {
      log(m).pair("lists", lists);
      await _api.putDevice(m, lists: lists);
      await fetch(m);
    });
  }

  @action
  Future<void> setDeviceName(String? deviceName, Marker m) async {
    // Simple handling of OG flavor (no generated device names)
    // TODO: refactor
    if (!act.isFamily()) {
      deviceAlias = deviceName!;
      return;
    }
  }

  @action
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isForeground()) return;
    if (!route.isMainRoute()) return;
    if (!isCooledDown(cfg.deviceRefreshCooldown)) return;

    return await log(m).trace("fetchDevice", (m) async {
      await fetch(m);
    });
  }

  @action
  Future<void> onAccountChanged(Marker m) async {
    return await log(m).trace("onAccountChanged", (m) async {
      await fetch(m);
    });
  }
}
