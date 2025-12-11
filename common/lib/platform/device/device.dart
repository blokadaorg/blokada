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

class DeviceStore = DeviceStoreBase with _$DeviceStore;

abstract class DeviceStoreBase with Store, Logging, Actor, Cooldown, Emitter {
  late final _api = Core.get<DeviceApi>();
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();
  late final _env = Core.get<EnvActor>();

  late final _journalFilter = Core.get<JournalFilterValue>();

  static const Duration _deviceCacheTtl = Duration(seconds: 30);
  DateTime? _lastDeviceFetch;
  String? _lastAccountId;

  DeviceStoreBase() {
    willAcceptOn([deviceChanged]);

    _stage.addOnValue(routeChanged, onRouteChanged);
    _account.addOn(accountChanged, onAccountChanged);
    _account.addOn(accountIdChanged, onAccountIdChanged);
  }

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

  @observable
  int pausedForSeconds = 0;

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
      await setDeviceName(_env.deviceName, m);

      // Only show current device journal by default
      _journalFilter.now = _journalFilter.now.updateOnly(deviceName: deviceAlias);
    });
  }

  @action
  Future<void> fetch(Marker m, {bool force = false}) async {
    if (Core.act.isFamily) return;

    if (!force && _isCacheValid()) {
      log(m).i("device fetch skipped (cache hit)");
      return;
    }

    return await log(m).trace("fetch", (m) async {
      log(m).pair("tagBeforeFetch", deviceTag);

      final device = await _api.getDevice(m);
      pausedForSeconds = device.pausedForSeconds;
      cloudEnabled = !device.paused;
      lists = device.lists;
      retention = device.retention;
      deviceTag = device.deviceTag;
      final now = DateTime.now();
      _lastDeviceFetch = now;
      lastRefresh = now;
      _lastAccountId = _account.account?.id;

      log(m).pair("pausedForSeconds", pausedForSeconds);
      log(m).pair("tagAfterFetch", deviceTag);
      await emit(deviceChanged, deviceTag!, m);
    });
  }

  @action
  Future<void> setCloudEnabled(Marker m, bool enabled, {Duration? pauseDuration}) async {
    final pauseSeconds = pauseDuration?.inSeconds;
    final shouldUpdate =
        cloudEnabled != enabled || (pauseSeconds != null && pauseSeconds != pausedForSeconds);
    if (!shouldUpdate) {
      log(m).i("setCloudEnabled noop, skipping device refresh");
      return;
    }

    return await log(m).trace("setCloudEnabled", (m) async {
      await _api.putDevice(m, paused: !enabled, pausedForSeconds: pauseSeconds);
      await fetch(m, force: true);
    });
  }

  @action
  Future<void> setRetention(DeviceRetention retention, Marker m) async {
    if (this.retention == retention) {
      log(m).i("setRetention noop, skipping device refresh");
      return;
    }

    return await log(m).trace("setRetention", (m) async {
      log(m).pair("retention", retention);
      await _api.putDevice(m, retention: retention);
      await fetch(m, force: true);
    });
  }

  @action
  Future<void> setLists(List<String> lists, Marker m) async {
    // Skip device updates in freemium mode to prevent refresh loops
    if (_account.isFreemium) {
      log(m).i("Skipping setLists in freemium mode");
      return;
    }

    if (_listsEqual(this.lists, lists)) {
      log(m).i("setLists noop, skipping device refresh");
      return;
    }
    
    return await log(m).trace("setLists", (m) async {
      log(m).pair("lists", lists);
      await _api.putDevice(m, lists: lists);
      await fetch(m, force: true);
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

    return await log(m).trace("fetchDevice", (m) async {
      await fetch(m);
    });
  }

  @action
  Future<void> onAccountChanged(Marker m) async {
    final id = _account.account?.id;
    if (id == null) return;
    if (id == _lastAccountId) {
      log(m).i("account id unchanged, skipping device refresh");
      return;
    }
    _lastAccountId = id;
    return await log(m).trace("onAccountChanged", (m) async {
      await fetch(m, force: true);
    });
  }

  @action
  Future<void> onAccountIdChanged(Marker m) async {
    final id = _account.account?.id;
    _lastAccountId = id;
    await fetch(m, force: true);
  }

  bool _isCacheValid() {
    if (deviceTag == null || _lastDeviceFetch == null) return false;
    return DateTime.now().difference(_lastDeviceFetch!) < _deviceCacheTtl;
  }

  bool _listsEqual(List<String>? a, List<String>? b) {
    if (a == null || b == null) return false;
    return Set.from(a) == Set.from(b);
  }
}
