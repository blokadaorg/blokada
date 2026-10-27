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
  // supported replacement. Keep the filename convention: <language>.json, or
  // <language>_<region>.json (the sync writes pt_br.json for pt-BR).
  static Future<Map<String, Map<String, String>>> _loadFromAssetDirectory(
      String dir) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final result = <String, Map<String, String>>{};
    final sources = <String, String>{};

    for (final path in manifest.listAssets()) {
      if (!path.startsWith(dir) || !path.endsWith(".json")) continue;
      final locale = localeTagFromFilename(path.split("/").last.split(".").first);
      final existing = sources[locale];
      if (existing != null) {
        throw StateError("Translation files $existing and $path both map to locale $locale");
      }
      sources[locale] = path;
      final source = await rootBundle.loadString(path);
      result[locale] = Map<String, String>.from(json.decode(source));
    }

    return result;
  }

  // i18n_extension normalizes the device locale to a BCP 47 tag (pt-BR) and
  // looks it up by exact match, so a file keyed "pt_br" would never be used.
  // Same casing rules as the library: language lower-case, 4-letter script
  // title-case, region upper-case.
  @visibleForTesting
  static String localeTagFromFilename(String name) {
    final parts = name.split(RegExp("[-_]"));
    if (parts.any((part) => part.isEmpty)) {
      throw ArgumentError.value(name, "name", "Not a locale filename");
    }
    return [
      parts.first.toLowerCase(),
      for (final part in parts.skip(1))
        part.length == 4
            ? part[0].toUpperCase() + part.substring(1).toLowerCase()
            : part.toUpperCase(),
    ].join("-");
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
