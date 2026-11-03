import 'package:common/src/core/core.dart';
import 'package:flutter/foundation.dart';

const commandLogLevel = "logLevel";

class ConfigCommand with Command, Logging {
  late final _logLevel = Core.get<ConfigLogLevel>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand(commandLogLevel, argsNum: 1, fn: cmdLogLevel),
    ];
  }

  Future<void> cmdLogLevel(Marker m, dynamic args) async {
    final msg = args[0] as String;
    _logLevel.change(m, msg);
  }
}

@PlatformProvided()
mixin ConfigChannel {
  // No need to expose logLevel to platform
  Future<void> doShareText(String text);
}

class ConfigActor with Actor {
  late final _logLevel = Core.get<ConfigLogLevel>();

  @override
  onCreate(Marker m) async {
    // For now this is how we use this command
    _logLevel.onChange.listen((value) {
      Core.config.obfuscateSensitiveParams =
          kReleaseMode && value.now != "verbose";
    });
  }

  @override
  onStart(Marker m) async {
    await _logLevel.fetch(m);
  }
}

class ConfigModule with Module {
  @override
  onCreateModule() async {
    await register(ConfigCommand());
    await register(ConfigActor());
  }
}
