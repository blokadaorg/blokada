import 'package:common/common/module/env/env.dart';
import 'package:common/common/module/journal/journal.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/util/cooldown.dart';
import 'package:mobx/mobx.dart';

import '../stage/stage.dart';
import 'api.dart';

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

abstract class DeviceStoreBase with Store, Logging, Actor, Cooldown, Emitter {
  late final _api = Core.get<DeviceApi>();
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();
  late final _persistence = Core.get<Persistence>();
  late final _env = Core.get<EnvActor>();

  late final _journalFilter = Core.get<JournalFilterValue>();

  DeviceStoreBase() {
    willAcceptOn([deviceChanged]);

    _stage.addOnValue(routeChanged, onRouteChanged);
    _account.addOn(accountChanged, onAccountChanged);
    _account.addOn(accountIdChanged, fetch);
  }

  @override
  onRegister() {
    Core.register<DeviceApi>(DeviceApi());
    Core.register<DeviceStore>(this as DeviceStore);
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
  Future<void> onStart(Marker m) async {
    return await log(m).trace("start", (m) async {
      await load(m);
      await setDeviceName(_env.deviceName, m);

      // Only show current device journal by default
      _journalFilter.now =
          _journalFilter.now.updateOnly(deviceName: deviceAlias);
    });
  }

  @action
  Future<void> load(Marker m) async {
    return await log(m).trace("load", (m) async {
      deviceAlias = await _persistence.load(m, _keyAlias) ?? "";
    });
  }

  @action
  Future<void> fetch(Marker m) async {
    if (Core.act.isFamily) return;

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
    if (!Core.act.isFamily) {
      deviceAlias = deviceName!;
      return;
    }
  }

  @action
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isForeground()) return;
    if (!route.isMainRoute()) return;
    if (!isCooledDown(Core.config.deviceRefreshCooldown)) return;

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
