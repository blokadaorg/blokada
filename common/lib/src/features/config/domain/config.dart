import 'package:common/src/core/core.dart';
import 'package:flutter/foundation.dart';

const commandLogLevel = "logLevel";
const commandSkipBypass = "skipBypassList";

// A temporary command to not use bypass list (android)
// Needed if someone is using "block connections outside vpn"
class ConfigPlusSkipBypassList extends BoolPersistedValue {
  ConfigPlusSkipBypassList() : super("config:plus:skipBypassList");
}

class ConfigCommand with Command, Logging {
  late final _logLevel = Core.get<ConfigLogLevel>();
  late final _skipBypass = Core.get<ConfigPlusSkipBypassList>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand(commandLogLevel, argsNum: 1, fn: cmdLogLevel),
      registerCommand(commandSkipBypass, argsNum: 1, fn: cmdSkipBypassList),
    ];
  }

  Future<void> cmdLogLevel(Marker m, dynamic args) async {
    final msg = args[0] as String;
    _logLevel.change(m, msg);
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
  // No need to expose logLevel to platform
  Future<void> doConfigChanged(bool skipBypassList);
  Future<void> doShareText(String text);
}

class ConfigActor with Actor {
  late final _channel = Core.get<ConfigChannel>();

  late final _logLevel = Core.get<ConfigLogLevel>();
  late final _skipBypass = Core.get<ConfigPlusSkipBypassList>();

  @override
  onCreate(Marker m) async {
    // For now this is how we use this command
    _logLevel.onChange.listen((value) {
      Core.config.obfuscateSensitiveParams =
          kReleaseMode && value.now != "verbose";
    });

    _skipBypass.onChange.listen((value) {
      _channel.doConfigChanged(value.now);
    });
  }

  @override
  onStart(Marker m) async {
    await _logLevel.fetch(m);
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
