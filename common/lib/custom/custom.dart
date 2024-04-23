import 'package:mobx/mobx.dart';

import '../stage/stage.dart';
import '../util/config.dart';
import '../util/cooldown.dart';
import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'custom.g.dart';

class CustomStore = CustomStoreBase with _$CustomStore;

abstract class CustomStoreBase with Store, Traceable, Dependable, Cooldown {
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
  attach(Act act) {
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
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      final entries = await _json.getEntries(trace);
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

      trace.addAttribute("deniedLength", denied.length);
      trace.addAttribute("allowedLength", allowed.length);
    });
  }

  @action
  Future<void> allow(Trace parentTrace, String domainName) async {
    return await traceWith(parentTrace, "allow", (trace) async {
      await _json.postEntry(
          trace, JsonCustomEntry(action: "allow", domainName: domainName));
      await fetch(trace);
    });
  }

  @action
  Future<void> deny(Trace parentTrace, String domainName) async {
    return await traceWith(parentTrace, "deny", (trace) async {
      await _json.postEntry(
          trace, JsonCustomEntry(action: "block", domainName: domainName));
      await fetch(trace);
    });
  }

  @action
  Future<void> delete(Trace parentTrace, String domainName) async {
    return await traceWith(parentTrace, "delete", (trace) async {
      await _json.deleteEntry(trace,
          JsonCustomEntry(action: "fallthrough", domainName: domainName));
      await fetch(trace);
    });
  }

  bool contains(String domainName) {
    return allowed.contains(domainName) || denied.contains(domainName);
  }

  // Will move to allowed it on blocked list, and vice versa.
  // Will do nothing if not existing.
  toggle(Trace parentTrace, String domainName) async {
    if (allowed.contains(domainName)) {
      await delete(parentTrace, domainName);
      await deny(parentTrace, domainName);
    } else if (denied.contains(domainName)) {
      await delete(parentTrace, domainName);
      await allow(parentTrace, domainName);
    }
  }

  // Will add to allowed, or blocked list if not existing, depending on bool.
  // Will remove if existing.
  addOrRemove(Trace parentTrace, String domainName,
      {required bool gotBlocked}) async {
    if (contains(domainName)) {
      await delete(parentTrace, domainName);
    } else if (gotBlocked) {
      await allow(parentTrace, domainName);
    } else {
      await deny(parentTrace, domainName);
    }
  }

  @action
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (!route.isForeground()) return;
    if (!route.isBecameTab(StageTab.activity)) return;
    if (!isCooledDown(cfg.customRefreshCooldown)) return;

    return await traceWith(parentTrace, "fetchCustom", (trace) async {
      await fetch(trace);
    });
  }
}
