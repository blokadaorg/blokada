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
  static const secure = "persistence:secure";
  static const standard = "persistence:standard";

  late final _channel = DI.get<PersistenceChannel>();

  final Marker _m = Markers.persistence;

  final bool isSecure;

  Persistence({required this.isSecure});

  Future<String?> load(String key, {bool isBackup = false}) async {
    try {
      final result = await _channel.doLoad(key, isSecure, isBackup);

      log(_m).t("load s/b $isSecure/$isBackup $key");
      log(_m).logt(attr: {"key": key, "value": result}, sensitive: true);

      return result;
    } on Exception catch (e, s) {
      // TODO: not all exceptions mean that the key is not found
      log(_m).e(msg: "load", err: e, stack: s);
      return null;
    }
  }

  Future<Map<String, dynamic>> loadJson(String key,
      {bool isBackup = false}) async {
    final result = await _channel.doLoad(key, isSecure, isBackup);

    log(_m).t("loadJson s/b $isSecure/$isBackup $key");
    log(_m).logt(attr: {"key": key, "value": result}, sensitive: true);

    return jsonDecode(result);
  }

  Future<void> save(String key, String value, {bool isBackup = false}) async {
    log(_m).t("save s/b $isSecure/$isBackup $key");
    log(_m).logt(attr: {"key": key, "value": value}, sensitive: true);

    await _channel.doSave(key, value, isSecure, isBackup);
  }

  Future<void> saveJson(String key, Map<String, dynamic> json,
      {bool isBackup = false}) async {
    log(_m).t("save s/b $isSecure/$isBackup $key");
    log(_m).logt(attr: {"key": key, "value": json}, sensitive: true);

    await _channel.doSave(key, jsonEncode(json), isSecure, isBackup);
  }

  Future<void> delete(String key, {bool isBackup = false}) async {
    log(_m).t("delete s/b $isSecure/$isBackup $key");

    await _channel.doDelete(key, isSecure, isBackup);
  }
}
