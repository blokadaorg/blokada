part of 'family.dart';

class FamilyCommand with Command {
  late final _actor = Core.get<LinkActor>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand("familyLink", argsNum: 1, fn: cmdLink),
      registerCommand("familyLinkExternal", argsNum: 1, fn: cmdLinkExternal),
    ];
  }

  /// A link scanned with the app's own QR scanner on Android or iOS.
  Future<void> cmdLink(Marker m, dynamic args) async {
    final url = args[0] as String;
    return await _actor.requestLink(url, m, fromScanner: true);
  }

  /// A link opened from outside the app (app link, universal link, camera
  /// app). Any installed app can deliver one, so it is always confirmed.
  Future<void> cmdLinkExternal(Marker m, dynamic args) async {
    final url = args[0] as String;

    // Often arrives before the app is ready, so the link is parked. The
    // family UI resolves it once mounted, a real readiness signal.
    return await _actor.requestLink(url, m);
  }
}
