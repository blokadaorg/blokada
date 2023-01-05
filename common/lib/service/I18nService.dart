import 'package:i18n_extension/io/import.dart';
import 'package:i18n_extension/i18n_extension.dart';

class I18nService {

  static TranslationsByLocale translations = Translations.byLocale("en");

  static Future<void> loadTranslations() async {
    translations +=
    await JSONImporter().fromAssetDirectory("assets/translations");
  }

}

extension Localization on String {
  String get i18n => localize(this, I18nService.translations);
  String plural(value) => localizePlural(value, this, I18nService.translations);
  String fill(List<Object> params) => localizeFill(this, params);
}
