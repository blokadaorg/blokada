part of 'core.dart';

final commands = CommandCoordinator();

typedef Submodules = Future<List<Module>>;

mixin Module {
  final _actorStarter = ActorStarter();

  bool _created = false;
  bool _started = false;

  @nonVirtual
  create() async {
    if (_created) throw Exception("Module already created");
    _created = true;

    return await onCreateModule();
  }

  onCreateModule();

  Submodules onRegisterSubmodules() async => [];

  register<T extends Object>(T instance, {String? tag}) async {
    if (instance is Actor) {
      Core.register(instance, tag: tag);
      _actorStarter.add(instance);
      instance.create(Markers.root);
    } else if (instance is Command) {
      await commands.registerCommands(
          Markers.start, instance.onRegisterCommands());
    } else {
      Core.register(instance, tag: tag);
    }
  }

  @nonVirtual
  start(Marker m) async {
    if (_started) throw Exception("Module already started");
    _started = true;
    await _actorStarter.start(m);
  }
}

class ActorStarter with Logging {
  final List<Actor> actors = [];

  void add(Actor actor) {
    actors.add(actor);
  }

  Future<void> start(Marker m) async {
    for (final actor in actors) {
      await log(m).trace("${actor.runtimeType}", (m) async {
        await actor.start(m);
      });
    }
  }
}
