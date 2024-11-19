part of 'core.dart';

final commands = CommandCoordinator();

mixin Module {
  late final Act act;
  final _actorStarter = ActorStarter();

  bool _created = false;
  bool _started = false;

  @nonVirtual
  create(Act act) async {
    if (_created) throw Exception("Module already created");
    _created = true;

    this.act = act;
    await onCreateModule(act);
  }

  Future<void> onCreateModule(Act act);

  register<T extends Object>(T instance, {String? tag}) async {
    DI.register(instance, tag: tag);
    if (instance is Actor) {
      _actorStarter.add(instance);
      instance.act = act;
      instance.onCreate(Markers.root);
    } else if (instance is Command) {
      await commands.registerCommands(
          Markers.start, instance.onRegisterCommands());
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
        await actor.onStart(m);
      });
    }
  }
}
