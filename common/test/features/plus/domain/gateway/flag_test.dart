import 'package:common/src/features/plus/domain/gateway/gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countryFlag', () {
    test('maps alpha-2 codes to regional indicator pairs', () {
      expect(countryFlag('SE'), '\u{1F1F8}\u{1F1EA}');
      expect(countryFlag('ES'), '\u{1F1EA}\u{1F1F8}');
      expect(countryFlag('JP'), '\u{1F1EF}\u{1F1F5}');
    });

    test('accepts lowercase and surrounding whitespace', () {
      expect(countryFlag(' jp '), countryFlag('JP'));
    });

    test('returns null when the code is missing or not alpha-2', () {
      expect(countryFlag(null), isNull);
      expect(countryFlag(''), isNull);
      expect(countryFlag('S'), isNull);
      expect(countryFlag('SWE'), isNull);
      expect(countryFlag('S1'), isNull);
      expect(countryFlag('ÅL'), isNull);
    });
  });

  group('Gateway.flag', () {
    Gateway gateway(String? country) => Gateway('example-key', 'europe-north1', 'stockholm', 1,
        '192.0.2.1', '2001:db8::1', 51820, country);

    test('comes from the country code', () {
      expect(gateway('SE').flag, '\u{1F1F8}\u{1F1EA}');
    });

    test('is null without a country', () {
      expect(gateway(null).flag, isNull);
    });
  });
}
