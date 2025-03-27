part of 'core.dart';

class LoggerCommand with Command, Logging {
  late final _channel = Core.get<LoggerChannel>();
  late final _stage =
      Core.get<StageStore>(); // TODO: This should not be a dep of core
  late final _isLocked =
      Core.get<IsLocked>(); // TODO: This should not be a dep of core

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand("info", argsNum: 1, fn: cmdPlatformInfo),
      registerCommand("warning", argsNum: 1, fn: cmdPlatformWarning),
      registerCommand("fatal", argsNum: 1, fn: cmdPlatformFatal),
      registerCommand("log", argsNum: 0, fn: cmdShareLog),
    ];
  }

  Future<void> cmdPlatformInfo(Marker m, dynamic args) async {
    final msg = args[0] as String;
    log(m).i(msg);
  }

  Future<void> cmdPlatformWarning(Marker m, dynamic args) async {
    final msg = args[0] as String;
    log(m).w(msg);
  }

  Future<void> cmdPlatformFatal(Marker m, dynamic args) async {
    final msg = args[0] as String;
    log(m).e(msg: "FATAL: $msg");
  }

  Future<void> cmdShareLog(Marker m, dynamic args) async {
    if (_isLocked.now) {
      return await _stage.showModal(StageModal.faultLocked, m);
    }

    // Non-await delay to try to make sure the latest log batch is saved
    Future.delayed(const Duration(seconds: 2), () {
      print("Sharing log...");
      _channel.doShareFile();
    });
  }
}
