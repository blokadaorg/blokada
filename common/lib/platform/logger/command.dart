part of 'logger.dart';

class LoggerCommand with Command, Logging {
  late final _channel = Core.get<LoggerChannel>();
  late final _stage = Core.get<StageStore>();
  late final _isLocked = Core.get<IsLocked>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand("warning", argsNum: 1, fn: cmdPlatformWarning),
      registerCommand("fatal", argsNum: 1, fn: cmdPlatformFatal),
      registerCommand("log", argsNum: 0, fn: cmdShareLog),
    ];
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
    _channel.doShareFile();
  }

  // TODO: crash log stuff
}
