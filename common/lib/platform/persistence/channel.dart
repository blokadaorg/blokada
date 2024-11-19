part of 'persistence.dart';

class RuntimePersistenceChannel implements PersistenceChannel {
  final Map<String, String> _map = {};

  @override
  Future<void> doDelete(String key, bool isSecure, bool isBackup) async {}

  @override
  Future<String> doLoad(String key, bool isSecure, bool isBackup) async {
    if (!_map.containsKey(key)) {
      throw Exception("No (mocked) persistence for: $key");
    }
    return _map[key] ?? '';
  }

  @override
  Future<void> doSave(
      String key, String value, bool isSecure, bool isBackup) async {
    _map[key] = value;
  }
}

class PlatformPersistenceChannel with PersistenceChannel {
  late final _platform = PersistenceOps();

  @override
  Future<JsonString> doLoad(String key, bool isSecure, bool isBackup) {
    return _platform.doLoad(key, isSecure, isBackup);
  }

  @override
  Future<void> doSave(String key, String value, bool isSecure, bool isBackup) {
    return _platform.doSave(key, value, isSecure, isBackup);
  }

  @override
  Future<void> doDelete(String key, bool isSecure, bool isBackup) {
    return _platform.doDelete(key, isSecure, isBackup);
  }
}
