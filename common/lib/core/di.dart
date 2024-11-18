part of 'core.dart';

class DI {
  static final di = GetIt.instance;

  static void register<T extends Object>(T instance, {String? tag}) {
    di.registerSingleton<T>(instance, instanceName: tag ?? "default");
  }

  static T get<T extends Object>({String? tag}) {
    return di<T>(instanceName: tag ?? "default");
  }
}
