import 'package:get_it/get_it.dart';

final di = GetIt.instance;
final dep = di;

enum Platform { ios, android }

enum Flavor { og, family }

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

mixin Act {
  bool isProd();
  bool hasToys();
  bool isFamily();
  Platform getPlatform();
  Flavor getFlavor();
}
