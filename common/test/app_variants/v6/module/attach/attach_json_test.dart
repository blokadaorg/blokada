import 'package:common/src/app_variants/v6/module/attach/attach.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsonAttachMarshal', () {
    test('parses the hand-off token and its lifetime', () {
      final link = JsonAttachMarshal().toLink('''{
        "token": "some-token",
        "expires": "2026-09-22T10:05:00Z",
        "expires_in": 300
      }''');

      expect(link.token, 'some-token');
      expect(link.expires, '2026-09-22T10:05:00Z');
      expect(link.expiresIn, 300);
    });

    test('rejects a response without a token', () {
      expect(
        () => JsonAttachMarshal().toLink('{"expires_in": 300}'),
        throwsA(isA<JsonError>()),
      );
    });

    test('sends the account id as the placeholder Http substitutes', () {
      expect(JsonAttachMarshal().payload(), '{"account_id":"(account_id)"}');
    });
  });
}
