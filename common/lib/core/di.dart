part of 'core.dart';

final di = GetIt.instance;
final dep = di;

void depend<T extends Object>(T instance, {String? tag}) {
  dep.registerSingleton<T>(instance, instanceName: tag);
}

mixin Dependable {
  late final Act act;

  void attach(Act act);

  void attachAndSaveAct(Act act) {
    this.act = act;
    attach(act);
  }

  void setActForTest(Act act) {
    this.act = act;
  }
}

Answer<Future<void>> ignore() {
  return (_) async {};
}

mixin Startable {
  Future<void> start(Marker m);
}
