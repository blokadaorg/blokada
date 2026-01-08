part of '../core.dart';

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
  static const secure = "persistence:secure";
  static const standard = "persistence:standard";

  late final _channel = Core.get<PersistenceChannel>();

  final bool isSecure;

  Persistence({required this.isSecure});

  Future<String?> load(Marker m, String key, {bool isBackup = false}) async {
    try {
      final result = await _channel.doLoad(key, isSecure, isBackup);

      log(m).t("load (s:$isSecure, b:$isBackup)");
      log(m).logt(msg: "key: $key", attr: {"value": result}, sensitive: true);

      return result;
    } on Exception catch (e, s) {
      // TODO: not all exceptions mean that the key is not found
      log(m).t("error load '$key': ${e.toString().short()}...");
      return null;
    }
  }

  Future<Map<String, dynamic>> loadJson(Marker m, String key,
      {bool isBackup = false}) async {
    final result = await _channel.doLoad(key, isSecure, isBackup);

    log(m).t("loadJson (s:$isSecure, b:$isBackup)");
    log(m).logt(msg: "key: $key", attr: {"value": result}, sensitive: true);

    return jsonDecode(result);
  }

  save(Marker m, String key, String value, {bool isBackup = false}) async {
    log(m).t("save (s:$isSecure, b:$isBackup)");
    log(m).logt(msg: "key: $key", attr: {"value": value}, sensitive: true);

    await _channel.doSave(key, value, isSecure, isBackup);
  }

  saveJson(Marker m, String key, Map<String, dynamic> json,
      {bool isBackup = false}) async {
    log(m).t("save (s:$isSecure, b:$isBackup)");
    log(m).logt(msg: "key: $key", attr: {"value": json}, sensitive: true);

    await _channel.doSave(key, jsonEncode(json), isSecure, isBackup);
  }

  delete(Marker m, String key, {bool isBackup = false}) async {
    log(m).t("delete (s:$isSecure, b:$isBackup)");

    await _channel.doDelete(key, isSecure, isBackup);
  }
}
