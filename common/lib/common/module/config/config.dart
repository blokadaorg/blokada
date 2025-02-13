import 'package:common/core/core.dart';

class ConfigPlusVpnUseBypassList extends BoolPersistedValue {
  ConfigPlusVpnUseBypassList() : super("config:plus:vpnUseBypassList");
}

class ConfigCommand with Command, Logging {
  late final _useBypass = Core.get<ConfigPlusVpnUseBypassList>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand("useBypassList", argsNum: 1, fn: cmdUseBypassList),
    ];
  }

  Future<void> cmdUseBypassList(Marker m, dynamic args) async {
    final msg = args[0] as String;
    if (msg == "1") {
      _useBypass.change(m, true);
    } else {
      _useBypass.change(m, false);
    }
  }
}

@PlatformProvided()
mixin ConfigChannel {
  Future<void> doConfigChanged(bool useBypassList);
}

class ConfigActor with Actor {
  late final _useBypass = Core.get<ConfigPlusVpnUseBypassList>();
  late final _channel = Core.get<ConfigChannel>();

  @override
  onCreate(Marker m) async {
    _useBypass.onChange.listen((value) {
      _channel.doConfigChanged(value.now);
    });
  }

  @override
  onStart(Marker m) async {
    await _useBypass.fetch(m);
  }
}

class ConfigModule with Module {
  @override
  onCreateModule() async {
    await register(ConfigPlusVpnUseBypassList());
    await register(ConfigCommand());
    await register(ConfigActor());
  }
}
