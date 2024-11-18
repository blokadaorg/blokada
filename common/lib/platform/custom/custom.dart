import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';

import '../../util/cooldown.dart';
import '../../util/mobx.dart';
import '../stage/stage.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'custom.g.dart';

class CustomStore = CustomStoreBase with _$CustomStore;

abstract class CustomStoreBase with Store, Logging, Actor, Cooldown {
  late final _ops = dep<CustomOps>();
  late final _json = dep<CustomJson>();
  late final _stage = dep<StageStore>();

  CustomStoreBase() {
    reactionOnStore((_) => allowed, (allowed) async {
      await _ops.doCustomAllowedChanged(allowed);
    });

    reactionOnStore((_) => denied, (denied) async {
      await _ops.doCustomDeniedChanged(denied);
    });

    _stage.addOnValue(routeChanged, onRouteChanged);
  }

  @override
  onRegister(Act act) {
    depend<CustomOps>(getOps(act));
    depend<CustomJson>(CustomJson());
    depend<CustomStore>(this as CustomStore);
  }

  @observable
  List<String> denied = [];

  @observable
  List<String> allowed = [];

  @observable
  DateTime lastRefresh = DateTime(0);

  @action
  Future<void> fetch(Marker m) async {
    return await log(m).trace("fetch", (m) async {
      final entries = await _json.getEntries(m);
      denied = entries
          .where((e) => e.action == "block")
          .map((e) => e.domainName)
          .toList();
      denied.sort();

      allowed = entries
          .where((e) => e.action == "allow" || e.action == "fallthrough")
          .map((e) => e.domainName)
          .toList();
      allowed.sort();

      log(m).pair("deniedLength", denied.length);
      log(m).pair("allowedLength", allowed.length);
    });
  }

  @action
  Future<void> allow(String domainName, Marker m) async {
    return await log(m).trace("allow", (m) async {
      await _json.postEntry(
          JsonCustomEntry(action: "allow", domainName: domainName), m);
      await fetch(m);
    });
  }

  @action
  Future<void> deny(String domainName, Marker m) async {
    return await log(m).trace("deny", (m) async {
      await _json.postEntry(
          JsonCustomEntry(action: "block", domainName: domainName), m);
      await fetch(m);
    });
  }

  @action
  Future<void> delete(String domainName, Marker m) async {
    return await log(m).trace("delete", (m) async {
      await _json.deleteEntry(
          JsonCustomEntry(action: "fallthrough", domainName: domainName), m);
      await fetch(m);
    });
  }

  bool contains(String domainName) {
    return allowed.contains(domainName) || denied.contains(domainName);
  }

  // Will move to allowed it on blocked list, and vice versa.
  // Will do nothing if not existing.
  toggle(String domainName, Marker m) async {
    if (allowed.contains(domainName)) {
      //await delete(parentTrace, domainName);
      await deny(domainName, m);
    } else if (denied.contains(domainName)) {
      //await delete(parentTrace, domainName);
      await allow(domainName, m);
    }
  }

  // Will add to allowed, or blocked list if not existing, depending on bool.
  // Will remove if existing.
  addOrRemove(String domainName, Marker m, {required bool gotBlocked}) async {
    if (contains(domainName)) {
      await delete(domainName, m);
    } else if (gotBlocked) {
      await allow(domainName, m);
    } else {
      await deny(domainName, m);
    }
  }

  @action
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isForeground()) return;
    if (!route.isBecameTab(StageTab.activity)) return;
    if (!isCooledDown(cfg.customRefreshCooldown)) return;

    return await log(m).trace("fetchCustom", (m) async {
      await fetch(m);
    });
  }
}
