import 'package:mobx/mobx.dart';

import '../stage/stage.dart';
import '../util/config.dart';
import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'custom.g.dart';

class CustomStore = CustomStoreBase with _$CustomStore;

abstract class CustomStoreBase with Store, Traceable, Dependable {
  late final _ops = di<CustomOps>();
  late final _json = di<CustomJson>();
  late final _stage = di<StageStore>();

  CustomStoreBase() {
    reactionOnStore((_) => allowed, (allowed) async {
      await _ops.doCustomAllowedChanged(allowed);
    });

    reactionOnStore((_) => denied, (denied) async {
      await _ops.doCustomDeniedChanged(denied);
    });
  }

  @override
  attach() {
    depend<CustomJson>(CustomJson());
    depend<CustomOps>(CustomOps());
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
      await _json.postEntry(trace,
          JsonCustomEntry(action: "fallthrough", domainName: domainName));
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

  @action
  Future<void> maybeRefreshCustom(Trace parentTrace) async {
    return await traceWith(parentTrace, "maybeRefreshCustom", (trace) async {
      if (!_stage.isForeground) {
        return;
      }

      if (!_stage.route.isTop(StageTab.activity)) {
        return;
      }

      final now = DateTime.now();
      if (now.difference(lastRefresh).compareTo(cfg.customRefreshCooldown) >
          0) {
        await fetch(trace);
        lastRefresh = now;
        trace.addEvent("refreshed");
      }
    });
  }
}
