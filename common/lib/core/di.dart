part of 'core.dart';

final di = GetIt.instance;
final dep = di;

void depend<T extends Object>(T instance, {String? tag}) {
  dep.registerSingleton<T>(instance, instanceName: tag);
}
