import 'package:get_it/get_it.dart';

final di = GetIt.instance;
final dep = di;

void depend<T extends Object>(T instance) {
  dep.registerSingleton<T>(instance);
}

mixin Dependable {
  void attach(Act act);
}

mixin Act {
  bool isProd();
}
