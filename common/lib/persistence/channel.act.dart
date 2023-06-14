import 'package:mocktail/mocktail.dart';

import '../../util/di.dart';
import '../util/act.dart';
import 'channel.pg.dart';

class MockPersistenceOps extends Mock implements PersistenceOps {}

PersistenceOps getOps(Act act) {
  if (act.isProd()) {
    return PersistenceOps();
  }

  //final ops = MockPersistenceOps();
  //_actNormal(ops);
  //return ops;

  return RuntimePersistenceOps();
}

class RuntimePersistenceOps implements PersistenceOps {
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
