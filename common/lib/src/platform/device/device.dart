import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/app/launch_context.dart';
import 'package:common/src/util/cooldown.dart';
import 'package:flutter/foundation.dart' show setEquals;
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

/// Whether this install issued the current pause. v6 pause is one flag per
/// account on /v2/device, so a device can find itself paused by another one;
/// the backend does not say who paused, so each install remembers its own
/// (#455). Null until this install pauses or sees the account unpaused, so an
/// app updated while its own pause is on does not blame another device.
class PauseIssuedHereValue extends StringifiedPersistedValue<bool> {
  PauseIssuedHereValue() : super("device:pause_issued_here");

  @override
  String toStringified(bool value) => value ? "1" : "0";

  @override
  bool fromStringified(String value) => value == "1";
}

/// A pause this install did not start: Home says "Paused from another device"
/// instead of the plain off state. Only for active accounts, where resuming is
/// possible; an unknown origin ([issuedHere] null) never claims another device.
bool isPausedElsewhere({
  required bool accountActive,
  required bool? cloudEnabled,
  required bool? issuedHere,
}) =>
    accountActive && cloudEnabled == false && issuedHere == false;

class DeviceStore = DeviceStoreBase with _$DeviceStore;

abstract class DeviceStoreBase with Store, Logging, Actor, Cooldown, Emitter {
  late final _api = Core.get<DeviceApi>();
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();
  late final _env = Core.get<EnvActor>();
  late final _bootstrapIdentity = Core.get<BootstrapIdentityValue>();
  late final _pauseIssuedHere = Core.get<PauseIssuedHereValue>();

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
    Core.register<PauseIssuedHereValue>(PauseIssuedHereValue());
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
      // A pause that ended anywhere (resumed, timer ran out) is no longer
      // ours; the next one may come from another device.
      if (!device.paused) await _recordPauseOrigin(m, false);
      pausedForSeconds = device.pausedForSeconds;
      cloudEnabled = !device.paused;
      lists = device.lists;
      retention = device.retention;
      deviceTag = device.deviceTag;
      _hydrateAliasFromEnvIfNeeded();
      final now = DateTime.now();
      _lastDeviceFetch = now;
      lastRefresh = now;
      _lastAccountId = _account.account?.id;
      await _publishBootstrapIdentity(m);

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
      // Before the refresh, so Home never shows our own pause as remote.
      await _recordPauseOrigin(m, !enabled);
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

  /// Saves the blocklists to the v2 device. Returns true once the server took
  /// them, so callers confirm a save that really happened, not a skip. A
  /// failed refresh afterwards is only logged: the save itself went through.
  @action
  Future<bool> setLists(List<String> lists, Marker m) async {
    // Skip device updates in freemium mode to prevent refresh loops
    if (_account.isFreemium) {
      log(m).i("Skipping setLists in freemium mode");
      return false;
    }

    if (_listsEqual(this.lists, lists)) {
      log(m).i("setLists noop, skipping device refresh");
      return false;
    }

    return await log(m).trace("setLists", (m) async {
      log(m).pair("lists", lists);
      await _api.putDevice(m, lists: lists);
      this.lists = lists;
      try {
        await fetch(m, force: true);
      } catch (e, s) {
        log(m).e(msg: "setLists: refresh after save failed", err: e, stack: s);
      }
      return true;
    });
  }

  @action
  Future<void> setDeviceName(String? deviceName, Marker m) async {
    // Simple handling of OG flavor (no generated device names)
    // TODO: refactor
    if (!Core.act.isFamily) {
      deviceAlias = deviceName!;
      await _publishBootstrapIdentity(m);
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
      await _publishBootstrapIdentity(m);
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
    deviceTag = null;
    await _bootstrapIdentity.change(m, null);
    // A pause issued under the previous account says nothing about this one.
    await _recordPauseOrigin(m, null);
    await fetch(m, force: true);
  }

  Future<bool> restoreBootstrapIdentity(BootstrapIdentity? identity, Marker m) async {
    if (identity == null) return false;
    final accountId = _account.account?.id;
    if (accountId == null || identity.accountId != accountId) {
      deviceTag = null;
      return false;
    }
    deviceTag = identity.deviceTag;
    if ((identity.deviceAlias ?? '').isNotEmpty) {
      deviceAlias = identity.deviceAlias!;
    }
    _hydrateAliasFromEnvIfNeeded();
    _lastAccountId = identity.accountId;
    log(m).i("Restored deviceTag from bootstrap identity");
    return true;
  }

  Future<void> _publishBootstrapIdentity(Marker m) async {
    final account = _account.account;
    final tag = deviceTag;
    if (account == null || tag == null || tag.isEmpty) {
      return;
    }

    final cachedAlias = _bootstrapIdentity.present?.deviceAlias;
    final alias = deviceAlias.isEmpty ? cachedAlias : deviceAlias;

    await _bootstrapIdentity.change(
      m,
      BootstrapIdentity(
        accountId: account.id,
        accountType: account.type.name,
        activeUntil: account.jsonAccount.activeUntil,
        deviceTag: tag,
        deviceAlias: (alias?.isEmpty ?? true) ? null : alias,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Writes who issued the pause. Only a Home hint depends on it, so a failed
  /// write is logged and never aborts the device refresh or a pause the server
  /// already took; the hint then stays at its previous value.
  Future<void> _recordPauseOrigin(Marker m, bool? issuedHere) async {
    try {
      await _pauseIssuedHere.change(m, issuedHere);
    } catch (e, s) {
      log(m).e(msg: "Failed saving pause origin", err: e, stack: s);
    }
  }

  bool _isCacheValid() {
    if (deviceTag == null || _lastDeviceFetch == null) return false;
    return DateTime.now().difference(_lastDeviceFetch!) < _deviceCacheTtl;
  }

  bool _listsEqual(List<String>? a, List<String>? b) {
    if (a == null || b == null) return false;
    return setEquals(a.toSet(), b.toSet());
  }

  void _hydrateAliasFromEnvIfNeeded() {
    if (Core.act.isFamily || deviceAlias.isNotEmpty) {
      return;
    }

    final alias = _env.deviceName.trim();
    if (alias.isNotEmpty) {
      deviceAlias = alias;
    }
  }
}
