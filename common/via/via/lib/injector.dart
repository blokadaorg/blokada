part of 'via.dart';

class Injector {
  final _map = <String, Map<Type, dynamic>>{};
  bool _injected = false;

  register<T>(dynamic object, {String key = Via.ofDefault}) {
    if (_injected)
      throw Exception("Injector already injected, cannot register");

    if (!_map.containsKey(key)) {
      _map[key] = <Type, dynamic>{};
    }

    //if (!_map[key]!.containsKey(T)) {
    _map[key]![T] = object;
    //}
  }

  T get<T>({String key = Via.ofDefault}) {
    if (_map.containsKey(key)) {
      if (_map[key]!.containsKey(T)) {
        return _map[key]![T];
      }
    }

    return throw Exception("No inject ($key): $T");
  }

  inject() {
    if (_injected) throw Exception("Injector already injected");
    _injected = true;
    for (final map in _map.values) {
      for (final object in map.values) {
        if (object is Injectable) {
          object.inject();
        }
      }
    }
  }
}

final injector = Injector();
