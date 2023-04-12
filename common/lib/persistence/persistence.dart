import 'dart:convert';

import '../util/di.dart';
import '../util/trace.dart';
import 'channel.pg.dart';

abstract class PersistenceService {
  Future<void> save(Trace trace, String key, Map<String, dynamic> value);
  Future<Map<String, dynamic>?> load(Trace trace, String key);
  Future<Map<String, dynamic>> loadOrThrow(Trace trace, String key);
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
class PlatformPersistenceImpl extends SecurePersistenceService with Traceable {
  final bool isSecure;
  final bool isBackup;

  PlatformPersistenceImpl({required this.isSecure, required this.isBackup});

  late final _ops = di<PersistenceOps>();

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
  Future<Map<String, dynamic>?> load(Trace trace, String key) async {
    try {
      return await loadOrThrow(trace, key);
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
}

Future<void> init() async {
  di.registerSingleton<PersistenceOps>(PersistenceOps());

  final platform = PlatformPersistenceImpl(isSecure: true, isBackup: true);
  di.registerSingleton<SecurePersistenceService>(platform);
}
