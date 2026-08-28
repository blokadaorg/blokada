part of 'family.dart';

class FamilyCommand with Command {
  late final _actor = Core.get<LinkActor>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand("familyLink", argsNum: 1, fn: cmdLink),
    ];
  }

  Future<void> cmdLink(Marker m, dynamic args) async {
    final url = args[0] as String;

    // A camera-app QR scan calls this before the app is ready, so the link is
    // parked. The family UI resolves it once mounted, a real readiness signal.
    return await _actor.requestLink(url, m);
  }
}
