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

    // When entering from a camera app qr code scan, this will be called
    // by the OS very early, and since onStartApp is executed async to not
    // block the UI thread, we need to wait for the app to be ready.
    await sleepAsync(const Duration(seconds: 3));
    return await _actor.link(url, m);
  }
}
