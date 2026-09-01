import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:flutter_test/flutter_test.dart';

// A structurally valid JWT: three base64url segments. Not signed, not real.
const _jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJkZXZpY2VfdGFnIjoiYWJjIn0.c2lnbmF0dXJl';

void main() {
  group('parseFamilyLinkToken', () {
    test('extracts the token from a canonical link', () {
      expect(parseFamilyLinkToken('$familyLinkBase?token=$_jwt'), _jwt);
    });

    test('accepts a bare token, as delivered by Android CommandActivity', () {
      expect(parseFamilyLinkToken(_jwt), _jwt);
    });

    test('trims surrounding whitespace', () {
      expect(parseFamilyLinkToken('  $_jwt  '), _jwt);
    });

    test('ignores extra query parameters but still requires token', () {
      expect(parseFamilyLinkToken('$familyLinkBase?name=Kid&token=$_jwt'), _jwt);
    });

    test('rejects a link on another host', () {
      expect(
        parseFamilyLinkToken(
            'https://evil.example/family/link_device?token=$_jwt'),
        isNull,
      );
    });

    test('rejects a link with no token parameter', () {
      expect(parseFamilyLinkToken('$familyLinkBase?tag=abc&name=Kid'), isNull);
    });

    test('rejects an empty token parameter', () {
      expect(parseFamilyLinkToken('$familyLinkBase?token='), isNull);
    });

    test('rejects a bare string that is not a JWT', () {
      expect(parseFamilyLinkToken('not-a-token'), isNull);
    });

    test('rejects empty input', () {
      expect(parseFamilyLinkToken(''), isNull);
      expect(parseFamilyLinkToken('   '), isNull);
    });

    test('rejects an unparseable uri', () {
      expect(parseFamilyLinkToken('https://['), isNull);
    });
  });
}
