part of 'core.dart';

class Core {
  static final di = GetIt.instance;

  static void register<T extends Object>(T instance, {String? tag}) {
    di.registerSingleton<T>(instance, instanceName: tag ?? "default");
  }

  static T get<T extends Object>({String? tag}) {
    return di<T>(instanceName: tag ?? "default");
  }

  /// Use this instead of `di.isRegistered`: [register] always names the
  /// instance, so an unnamed `di.isRegistered<T>()` never finds it.
  static bool isRegistered<T extends Object>({String? tag}) {
    return di.isRegistered<T>(instanceName: tag ?? "default");
  }

  static late Act act;
  static late CoreConfig config;
}
