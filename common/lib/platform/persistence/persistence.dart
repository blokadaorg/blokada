import 'dart:convert';

import 'package:common/core/core.dart';

import 'ops.dart';

abstract class PersistenceService {
  Future<void> save(String key, Map<String, dynamic> value, Marker m,
      {bool isBackup});
  Future<void> saveString(String key, String value, Marker m, {bool isBackup});
  Future<String?> load(String key, Marker m, {bool isBackup});
  Future<Map<String, dynamic>> loadOrThrow(String key, Marker m,
      {bool isBackup});
  Future<void> delete(String key, Marker m, {bool isBackup});
}

abstract class SecurePersistenceService extends PersistenceService {}

class PlatformPersistence extends SecurePersistenceService with Actor, Logging {
  final bool isSecure;

  PlatformPersistence({required this.isSecure});

  @override
  onRegister(Act act) {
    depend<PersistenceChannel>(getOps(act));
    depend<PersistenceService>(this);
  }

  late final _ops = dep<PersistenceChannel>();

  @override
  Future<Map<String, dynamic>> loadOrThrow(String key, Marker m,
      {bool isBackup = false}) async {
    log(m).log(
        msg: "loadOrThrow",
        attr: {"key": key, "isSecure": isSecure, "isBackup": isBackup});

    final result = await _ops.doLoad(key, isSecure, isBackup);
    final parsed = jsonDecode(result);
    return parsed;
  }

  @override
  Future<String?> load(String key, Marker m, {bool isBackup = false}) async {
    try {
      log(m).log(
          msg: "load",
          attr: {"key": key, "isSecure": isSecure, "isBackup": isBackup});

      return await _ops.doLoad(key, isSecure, isBackup);
    } on Exception {
      // TODO: not all exceptions mean that the key is not found
      return null;
    }
  }

  @override
  Future<void> save(String key, Map<String, dynamic> value, Marker m,
      {bool isBackup = false}) async {
    log(m).log(
        msg: "save",
        attr: {"key": key, "isSecure": isSecure, "isBackup": isBackup});

    await _ops.doSave(key, jsonEncode(value), isSecure, isBackup);
  }

  @override
  Future<void> saveString(String key, String value, Marker m,
      {bool isBackup = false}) async {
    log(m).log(
        msg: "saveString",
        attr: {"key": key, "isSecure": isSecure, "isBackup": isBackup});

    await _ops.doSave(key, value, isSecure, isBackup);
  }

  @override
  Future<void> delete(String key, Marker m, {bool isBackup = false}) async {
    log(m).log(
        msg: "delete",
        attr: {"key": key, "isSecure": isSecure, "isBackup": isBackup});

    await _ops.doDelete(key, isSecure, isBackup);
  }
}
