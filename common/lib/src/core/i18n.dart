part of 'core.dart';

class I18nService {
  static var translations = Translations.byLocale("en");

  static Future<void> loadTranslations() async {
    translations += await JSONImporter().fromAssetDirectory("assets/translations/ui");
    translations += await JSONImporter().fromAssetDirectory("assets/translations/packs");
    translations += await JSONImporter().fromAssetDirectory("assets/translations/packtags");
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
