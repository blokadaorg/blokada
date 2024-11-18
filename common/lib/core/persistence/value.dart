part of '../core.dart';

abstract class BoolPersistedValue extends NullableValue<bool?> {
  late final _persistence = DI.get<Persistence>();

  abstract final String key;

  @override
  Future<bool> doLoad() async {
    return await _persistence.load(key) == "1";
  }

  @override
  doSave(bool? value) async {
    if (value == null) {
      await _persistence.delete(key);
      return;
    }
    await _persistence.save(key, value ? "1" : "0");
  }
}

abstract class StringPersistedValue extends NullableValue<String?> {
  late final _persistence = DI.get<Persistence>();

  abstract final String key;

  @override
  Future<String?> doLoad() async {
    return await _persistence.load(key);
  }

  @override
  doSave(String? value) async {
    if (value == null) {
      await _persistence.delete(key);
      return;
    }
    await _persistence.save(key, value);
  }
}
