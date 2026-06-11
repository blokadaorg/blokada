import 'package:common/src/features/filter/domain/filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultFilters template fallback', () {
    test('family flavor: empty template falls back to family defaults, not v6',
        () {
      final family = DefaultFilters(true);
      // The family +New profile flow calls addProfile("", ...), so the empty
      // template must resolve to the family defaults whose filter names the
      // family KnownFilters contain. Returning the v6 set here made
      // FilterActor.getConfig throw and abort profile creation.
      expect(family.getTemplate(""), equals(family.getTemplate("family")));
      expect(
        family.getTemplate(""),
        isNot(equals(DefaultFilters(false).getTemplate(""))),
      );
    });

    test('v6 flavor: empty template still resolves to the v6 defaults', () {
      final v6 = DefaultFilters(false);
      expect(v6.getTemplate(""), equals(v6.getTemplate(null)));
    });
  });
}
