part of 'core.dart';

/// Persistence
///
/// I decided to use native channels for the persistence, since existing
/// Flutter libraries seem rather immature for what we need, and would bring
/// potential bugs while the solution is actually reasonably easy.
///
/// What we need from the platforms is those types of simple string storage:
/// - local storage
/// - automatically backed up storage (iCloud on iOS, Google Drive on Android)
/// - encrypted storage also automatically backed up

mixin PersistenceChannel {
  Future<JsonString> doLoad(String key, bool isSecure, bool isBackup);
  Future<void> doSave(
      String key, JsonString value, bool isSecure, bool isBackup);
  Future<void> doDelete(String key, bool isSecure, bool isBackup);
}

class Persistence with Logging {
  late final _channel = dep<PersistenceChannel>();

  final bool isSecure;

  Persistence({required this.isSecure});

  Future<JsonString> loadOrThrow(String key, {bool isBackup = false}) async {
    log(Markers.persistence).log(
      lvl: Level.trace,
      msg: "loadOrThrow",
      attr: {"key": key, "isSecure": isSecure, "isBackup": isBackup},
    );

    return await _channel.doLoad(key, isSecure, isBackup);
  }

  Future<JsonString?> load(String key, {bool isBackup = false}) async {
    try {
      log(Markers.persistence).log(
        lvl: Level.trace,
        msg: "load",
        attr: {"key": key, "isSecure": isSecure, "isBackup": isBackup},
      );

      return await _channel.doLoad(key, isSecure, isBackup);
    } on Exception catch (e, s) {
      // TODO: not all exceptions mean that the key is not found
      log(Markers.persistence).e(msg: "load", err: e, stack: s);
      return null;
    }
  }

  Future<void> save(String key, JsonString value,
      {bool isBackup = false}) async {
    log(Markers.persistence).log(
      lvl: Level.trace,
      msg: "save",
      attr: {"key": key, "isSecure": isSecure, "isBackup": isBackup},
    );

    await _channel.doSave(key, value, isSecure, isBackup);
  }

  Future<void> delete(String key, {bool isBackup = false}) async {
    log(Markers.persistence).log(
      lvl: Level.trace,
      msg: "delete",
      attr: {"key": key, "isSecure": isSecure, "isBackup": isBackup},
    );

    await _channel.doDelete(key, isSecure, isBackup);
  }
}
