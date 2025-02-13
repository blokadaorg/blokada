part of '../core.dart';

abstract class BoolPersistedValue extends AsyncValue<bool> {
  late final _persistence = Core.get<Persistence>();

  // Always assumes that default value is false!
  BoolPersistedValue(String key) {
    load = (Marker m) async {
      return await _persistence.load(m, key) == "1";
    };
    save = (Marker m, bool value) async {
      await _persistence.save(m, key, value ? "1" : "");
    };
  }
}

abstract class StringPersistedValue extends NullableAsyncValue<String?> {
  late final _persistence = Core.get<Persistence>();

  StringPersistedValue(String key) {
    load = (Marker m) async {
      return await _persistence.load(m, key);
    };
    save = (Marker m, String? value) async {
      if (value == null) {
        await _persistence.delete(m, key);
        return;
      }
      await _persistence.save(m, key, value);
    };
  }
}

abstract class JsonPersistedValue<T> extends NullableAsyncValue<T?> {
  final bool secure;

  late final _persistence =
      Core.get<Persistence>(tag: secure ? Persistence.secure : null);

  JsonPersistedValue(String key, {this.secure = false}) {
    load = (Marker m) async {
      final json = await _persistence.load(m, key);
      if (json == null) return null;
      return fromJson(jsonDecode(json));
    };
    save = (Marker m, T? value) async {
      if (value == null) {
        await _persistence.delete(m, key);
        return;
      }
      await _persistence.save(m, key, jsonEncode(toJson(value)));
    };
  }

  Map<String, dynamic> toJson(T value);
  T fromJson(Map<String, dynamic> json);
}
