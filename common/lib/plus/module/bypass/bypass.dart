import 'package:common/core/core.dart';
import 'package:common/plus/widget/vpn_bypass_dialog.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';

part 'actor.dart';
part 'channel.dart';

class BypassedPackagesValue extends StringifiedPersistedValue<Set<String>> {
  BypassedPackagesValue() : super("bypass:bypassedPackages");

  @override
  Set<String> fromStringified(String value) {
    return (value.isEmpty ? <String>[] : value.split(",")).toSet();
  }

  @override
  String toStringified(Set<String> value) {
    return value.join(",");
  }
}

class BypassedAppsValue extends Value<List<InstalledApp>> {
  BypassedAppsValue() : super(load: () => []);
}

class BypassModule with Module {
  @override
  onCreateModule() async {
    await register(BypassedPackagesValue());
    await register(BypassedAppsValue());
    await register(BypassActor());
    await register(BypassAddDialog());
  }
}
