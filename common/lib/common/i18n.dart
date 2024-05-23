import 'package:i18n_extension/i18n_extension.dart';
import 'package:i18n_extension_importer/i18n_extension_importer.dart';

class I18nService {
  static var translations = Translations.byLocale("en");

  static Future<void> loadTranslations() async {
    translations +=
        await JSONImporter().fromAssetDirectory("assets/translations/ui");
    translations +=
        await JSONImporter().fromAssetDirectory("assets/translations/packs");
    translations +=
        await JSONImporter().fromAssetDirectory("assets/translations/packtags");
  }
}

extension Localization on String {
  String get i18n => localize(this, I18nService.translations);
  String plural(value) => localizePlural(value, this, I18nService.translations);
  String fill(List<Object> params) => localizeFill(this, params);

  String withParams(Object param1, [Object? param2]) {
    if (param2 == null) {
      return replaceAll("%s", param1.toString());
    }
    return replaceFirst("%s", param1.toString())
        .replaceAll("%s", param2.toString());
  }
}
