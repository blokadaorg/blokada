part of 'plus.dart';

class PlusCommand with Command, Logging {
  late final _plus = Core.get<PlusActor>();
  late final _vpn = Core.get<VpnActor>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand("newPlus", fn: cmdNewPlus, argsNum: 1),
      registerCommand("vpnStatus", fn: cmdVpnStatus, argsNum: 1),
    ];
  }

  Future<void> cmdNewPlus(Marker m, dynamic args) async {
    final id = args[0] as String;
    await _plus.newPlus(id, m);
  }

  Future<void> cmdVpnStatus(Marker m, dynamic args) async {
    final status = args[0] as String;
    await _vpn.setActualStatus(status, m);
  }
}
