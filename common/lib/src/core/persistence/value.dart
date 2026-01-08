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

  StringPersistedValue(String key, {super.sensitive = true}) : super() {
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

  JsonPersistedValue(String key, {this.secure = false})
      : super(sensitive: true) {
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

// Persists any object by "stringifying" it using overridden methods.
abstract class StringifiedPersistedValue<T> extends NullableAsyncValue<T?>
    with Logging {
  late final _persistence = Core.get<Persistence>();

  StringifiedPersistedValue(String key, {super.sensitive = false}) : super() {
    load = (Marker m) async {
      final value = await _persistence.load(m, key);
      if (value == null) return null;
      return fromStringified(value);
    };
    save = (Marker m, T? value) async {
      if (value == null) {
        await _persistence.delete(m, key);
        return;
      }
      await _persistence.save(m, key, toStringified(value));
    };
  }

  String toStringified(T value);
  T fromStringified(String value);
}
