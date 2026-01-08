part of 'filter.dart';

class FilterCommand with Command, Logging {
  late final _actor = Core.get<PlatformFilterActor>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand("enableDeck", argsNum: 1, fn: cmdEnableDeck),
      registerCommand("disableDeck", argsNum: 1, fn: cmdDisableDeck),
      registerCommand("toggleListByTag", argsNum: 2, fn: cmdToggleListByTag),
    ];
  }

  Future<void> cmdEnableDeck(Marker m, dynamic args) async {
    final filterName = args[0] as String;
    await _actor.enableFilter(filterName, m);
  }

  Future<void> cmdDisableDeck(Marker m, dynamic args) async {
    final filterName = args[0] as String;
    await _actor.disableFilter(filterName, m);
  }

  Future<void> cmdToggleListByTag(Marker m, dynamic args) async {
    final filterName = args[0] as String;
    final option = args[1] as String;
    await _actor.toggleFilterOption(filterName, option, m);
  }
}
