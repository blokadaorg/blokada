part of 'core.dart';

typedef CommandFn = Future<void> Function(Marker m, dynamic args);

class CommandSpec {
  final String name;
  final int argsNum;
  final bool trace;
  final CommandFn fn;

  CommandSpec(this.name, this.argsNum, this.trace, this.fn);
}

mixin Command {
  List<CommandSpec> onRegisterCommands();

  CommandSpec registerCommand(
    String name, {
    required CommandFn fn,
    int argsNum = 0,
    bool trace = true,
  }) =>
      CommandSpec(name.toUpperCase(), argsNum, trace, fn);
}

class CommandCoordinator with Logging {
  final _commands = <String, CommandSpec>{};

  registerCommands(Marker m, List<CommandSpec> specs) async {
    return await log(m).trace("registerCommands", (m) async {
      for (final spec in specs) {
        log(m).t(spec.name);
        _commands[spec.name] = spec;
      }
    });
  }

  Future<void> execute(Marker m, String name, dynamic args) async {
    final n = name.toUpperCase();
    final spec = _commands[n];
    if (spec == null) {
      throw Exception("Command not found: $n");
    }

    if (spec.argsNum > 0) {
      if (args == null || args is! List) {
        throw Exception("Invalid argument for command $n");
      } else if (args.length != spec.argsNum) {
        throw Exception("Invalid number of arguments for command $n");
      }
    }

    if (spec.trace) {
      return await log(m).trace("cmd::$n(?)", (m) async {
        await spec.fn(m, args);
      });
    }

    await spec.fn(m, args);
  }
}
