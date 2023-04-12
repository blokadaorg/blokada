import 'package:mobx/mobx.dart';

import '../util/di.dart';
import '../util/trace.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'custom.g.dart';

class CustomStore = CustomStoreBase with _$CustomStore;

abstract class CustomStoreBase with Store, Traceable {
  late final _json = di<CustomJson>();

  @observable
  List<String> denied = [];

  @observable
  List<String> allowed = [];

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
}

class CustomBinder with CustomEvents, Traceable {
  late final _store = di<CustomStore>();
  late final _ops = di<CustomOps>();

  CustomBinder() {
    CustomEvents.setup(this);
    _onCustomAllowedChanged();
    _onCustomDeniedChanged();
  }

  CustomBinder.forTesting() {
    _onCustomAllowedChanged();
    _onCustomDeniedChanged();
  }

  @override
  Future<void> onAllow(String domainName) async {
    await traceAs("onAllow", (trace) async {
      await _store.allow(trace, domainName);
    });
  }

  @override
  Future<void> onDeny(String domainName) async {
    await traceAs("onDeny", (trace) async {
      await _store.deny(trace, domainName);
    });
  }

  @override
  Future<void> onDelete(String domainName) async {
    await traceAs("onDelete", (trace) async {
      await _store.delete(trace, domainName);
    });
  }

  @override
  Future<void> onStartListening() async {
    await traceAs("onStartListening", (trace) async {
      _ops.doCustomAllowedChanged(_store.allowed);
      _ops.doCustomDeniedChanged(_store.denied);
    });
  }

  _onCustomAllowedChanged() {
    reaction((_) => _store.allowed, (allowed) async {
      await traceAs("onCustomAllowedChanged", (trace) async {
        await _ops.doCustomAllowedChanged(allowed);
      });
    });
  }

  _onCustomDeniedChanged() {
    reaction((_) => _store.denied, (denied) async {
      await traceAs("onCustomDeniedChanged", (trace) async {
        await _ops.doCustomDeniedChanged(denied);
      });
    });
  }
}

Future<void> init() async {
  di.registerSingleton<CustomJson>(CustomJson());
  di.registerSingleton<CustomStore>(CustomStore());
  di.registerSingleton<CustomOps>(CustomOps());
  CustomBinder();
}
