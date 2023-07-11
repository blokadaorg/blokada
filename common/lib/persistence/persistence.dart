import 'dart:convert';

import '../util/di.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

abstract class PersistenceService {
  Future<void> save(Trace trace, String key, Map<String, dynamic> value);
  Future<void> saveString(Trace trace, String key, String value);
  Future<String?> load(Trace trace, String key);
  Future<Map<String, dynamic>> loadOrThrow(Trace trace, String key);
  Future<void> delete(Trace trace, String key);
}

abstract class SecurePersistenceService extends PersistenceService {}

/// PlatformPersistenceImpl
///
/// I decided to use native channels for the persistence, since existing
/// Flutter libraries seem rather immature for what we need, and would bring
/// potential bugs while the solution is actually reasonably easy.
///
/// What we need from the platforms is those types of simple string storage:
/// - local storage
/// - automatically backed up storage (iCloud on iOS, Google Drive on Android)
/// - encrypted storage also automatically backed up
class PlatformPersistence extends SecurePersistenceService
    with Traceable, Dependable {
  final bool isSecure;
  final bool isBackup;

  PlatformPersistence({required this.isSecure, required this.isBackup});

  @override
  attach(Act act) {
    depend<PersistenceOps>(getOps(act));
    depend<PersistenceService>(this);
  }

  late final _ops = dep<PersistenceOps>();

  @override
  Future<Map<String, dynamic>> loadOrThrow(Trace trace, String key) async {
    return await traceWith(trace, "loadOrThrow", (trace) async {
      trace.addAttribute("key", key);
      trace.addAttribute("isSecure", isSecure);
      trace.addAttribute("isBackup", isBackup);
      final result = await _ops.doLoad(key, isSecure, isBackup);
      final parsed = jsonDecode(result);
      return parsed;
    });
  }

  @override
  Future<String?> load(Trace trace, String key) async {
    try {
      trace.addAttribute("key", key);
      trace.addAttribute("isSecure", isSecure);
      trace.addAttribute("isBackup", isBackup);
      return await _ops.doLoad(key, isSecure, isBackup);
    } on Exception {
      // TODO: not all exceptions mean that the key is not found
      return null;
    }
  }

  @override
  Future<void> save(Trace trace, String key, Map<String, dynamic> value) async {
    return await traceWith(trace, "save", (trace) async {
      trace.addAttribute("key", key);
      trace.addAttribute("isSecure", isSecure);
      trace.addAttribute("isBackup", isBackup);
      await _ops.doSave(key, jsonEncode(value), isSecure, isBackup);
    });
  }

  @override
  Future<void> saveString(Trace trace, String key, String value) async {
    return await traceWith(trace, "saveString", (trace) async {
      trace.addAttribute("key", key);
      trace.addAttribute("isSecure", isSecure);
      trace.addAttribute("isBackup", isBackup);
      await _ops.doSave(key, value, isSecure, isBackup);
    });
  }

  @override
  Future<void> delete(Trace trace, String key) async {
    return await traceWith(trace, "delete", (trace) async {
      trace.addAttribute("key", key);
      trace.addAttribute("isSecure", isSecure);
      trace.addAttribute("isBackup", isBackup);
      await _ops.doDelete(key, isSecure, isBackup);
    });
  }
}
