part of 'support.dart';

class SupportCommand with Command, Logging {
  late final _actor = DI.get<SupportActor>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand("supportNotify", fn: cmdNotify),
    ];
  }

  Future<void> cmdNotify(Marker m, dynamic args) async {
    await sleepAsync(const Duration(seconds: 5));
    await _actor.sendEvent(SupportEvent.purchaseTimeout, m);
  }
}
