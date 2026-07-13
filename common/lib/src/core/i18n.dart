part of 'core.dart';

class I18nService {
  static var translations = Translations.byLocale("en");

  static Future<void> loadTranslations() async {
    translations += await _loadFromAssetDirectory("assets/translations/ui");
    translations += await _loadFromAssetDirectory("assets/translations/packs");
    translations += await _loadFromAssetDirectory("assets/translations/packtags");
  }

  // Replaces i18n_extension_importer's JSONImporter.fromAssetDirectory. That
  // package (0.0.6, abandoned since 2023) reads the legacy "AssetManifest.json",
  // which Flutter no longer ships. On 3.44 it threw "Unable to load asset:
  // AssetManifest.json" out of loadTranslations, and since nothing caught it the
  // app came up on a blank screen. AssetManifest.loadFromAssetBundle is the
  // supported replacement. Keep the filename convention: <language>.json.
  static Future<Map<String, Map<String, String>>> _loadFromAssetDirectory(
      String dir) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final result = <String, Map<String, String>>{};

    for (final path in manifest.listAssets()) {
      if (!path.startsWith(dir) || !path.endsWith(".json")) continue;
      final language = path.split("/").last.split(".").first;
      final source = await rootBundle.loadString(path);
      result[language] = Map<String, String>.from(json.decode(source));
    }

    return result;
  }
}

extension Localization on String {
  String get i18n => localize(this, I18nService.translations);
  String plural(value) => localizePlural(value, this, I18nService.translations);
  String fill(List<Object> params) => localizeFill(this, params);

  String withParams(Object param1, [Object? param2, Object? param3, bool lastReplacesAll = true]) {
    if (!lastReplacesAll) {
      if (param2 == null && param3 == null) {
        return replaceFirst("%s", param1.toString());
      }
      if (param3 == null) {
        return replaceFirst("%s", param1.toString()).replaceFirst("%s", param2.toString());
      }
      return replaceFirst("%s", param1.toString())
          .replaceFirst("%s", param2.toString())
          .replaceFirst("%s", param3.toString());
    }

    if (param2 == null && param3 == null) {
      return replaceAll("%s", param1.toString());
    }
    if (param3 == null) {
      return replaceFirst("%s", param1.toString()).replaceFirst("%s", param2.toString());
    }
    return replaceFirst("%s", param1.toString())
        .replaceFirst("%s", param2.toString())
        .replaceFirst("%s", param3.toString());
  }
}
