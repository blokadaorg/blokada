import 'package:common/core/core.dart';

class ConfigPlusSkipBypassList extends BoolPersistedValue {
  ConfigPlusSkipBypassList() : super("config:plus:skipBypassList");
}

class ConfigCommand with Command, Logging {
  late final _skipBypass = Core.get<ConfigPlusSkipBypassList>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand("skipBypassList", argsNum: 1, fn: cmdSkipBypassList),
    ];
  }

  Future<void> cmdSkipBypassList(Marker m, dynamic args) async {
    final msg = args[0] as String;
    if (msg == "1") {
      _skipBypass.change(m, true);
    } else {
      _skipBypass.change(m, false);
    }
  }
}

@PlatformProvided()
mixin ConfigChannel {
  Future<void> doConfigChanged(bool skipBypassList);
}

class ConfigActor with Actor {
  late final _skipBypass = Core.get<ConfigPlusSkipBypassList>();
  late final _channel = Core.get<ConfigChannel>();

  @override
  onCreate(Marker m) async {
    _skipBypass.onChange.listen((value) {
      _channel.doConfigChanged(value.now);
    });
  }

  @override
  onStart(Marker m) async {
    await _skipBypass.fetch(m);
  }
}

class ConfigModule with Module {
  @override
  onCreateModule() async {
    await register(ConfigPlusSkipBypassList());
    await register(ConfigCommand());
    await register(ConfigActor());
  }
}
