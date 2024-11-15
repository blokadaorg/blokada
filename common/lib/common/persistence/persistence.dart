import '../../persistence/channel.pg.dart';
import '../../util/di.dart';
import '../model.dart';

class Persistence {
  late final _ops = dep<PersistenceOps>();

  final bool isSecure;

  Persistence({required this.isSecure});

  Future<JsonString> loadOrThrow(String key, {bool isBackup = false}) async {
    return await _ops.doLoad(key, isSecure, isBackup);
  }

  Future<JsonString?> load(String key, {bool isBackup = false}) async {
    try {
      return await _ops.doLoad(key, isSecure, isBackup);
    } on Exception {
      // TODO: not all exceptions mean that the key is not found
      return null;
    }
  }

  Future<void> save(String key, JsonString value,
      {bool isBackup = false}) async {
    await _ops.doSave(key, value, isSecure, isBackup);
  }

  Future<void> delete(String key, {bool isBackup = false}) async {
    await _ops.doDelete(key, isSecure, isBackup);
  }
}
