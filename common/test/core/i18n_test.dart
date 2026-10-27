import 'package:common/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';

String _in(String languageTag, String key) =>
    localize(key, I18nService.translations, languageTag: languageTag);

void main() {
  group("localeTagFromFilename", () {
    test("keeps plain language codes", () {
      for (final name in ["ar", "de", "en", "pt", "zh"]) {
        expect(I18nService.localeTagFromFilename(name), name);
      }
    });

    test("maps language_region to a BCP 47 tag", () {
      expect(I18nService.localeTagFromFilename("pt_br"), "pt-BR");
      expect(I18nService.localeTagFromFilename("pt-BR"), "pt-BR");
      expect(I18nService.localeTagFromFilename("zh_hant"), "zh-Hant");
    });

    test("rejects malformed names", () {
      expect(() => I18nService.localeTagFromFilename("pt_"), throwsArgumentError);
    });
  });

  group("loadTranslations", () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await I18nService.loadTranslations();
    });

    test("pt-BR uses pt_br.json", () {
      // The stale pt-BR.json had "Edit" here.
      expect(_in("pt-BR", "universal action edit"), "Editar");
      // Only in pt_br.json; European Portuguese says "A carregar...".
      expect(_in("pt-BR", "universal status loading"), "Carregando...");
    });

    test("plain locales are unchanged", () {
      expect(_in("de", "universal action edit"), "Ändern");
      expect(_in("pt", "universal status loading"), "A carregar...");
    });
  });
}
