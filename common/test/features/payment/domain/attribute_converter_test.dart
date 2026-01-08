import 'package:common/src/features/payment/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptyAttributeConverter', () {
    test('converts valid attributes correctly', () {
      final attributes = {
        'feature_enabled': true,
        'user_level': 5,
        'score': 99.5,
        'username': 'john_doe',
      };

      final result = AdaptyAttributeConverter.convertToCustomAttributes(attributes);

      expect(result, hasLength(4));
      
      // Check boolean conversion
      final featureAttr = result.firstWhere((attr) => attr['key'] == 'feature_enabled');
      expect(featureAttr['value'], equals('true'));
      
      // Check integer conversion to double
      final levelAttr = result.firstWhere((attr) => attr['key'] == 'user_level');
      expect(levelAttr['value'], equals(5.0));
      
      // Check double value
      final scoreAttr = result.firstWhere((attr) => attr['key'] == 'score');
      expect(scoreAttr['value'], equals(99.5));
      
      // Check string value
      final usernameAttr = result.firstWhere((attr) => attr['key'] == 'username');
      expect(usernameAttr['value'], equals('john_doe'));
    });

    test('filters out timestamp values', () {
      final attributes = {
        'feature_enabled': true,
        'feature_expires_at': '2025-06-16T10:04:25.74971924Z',
        'created_at': DateTime.now(),
        'valid_field': 'keep_this',
      };

      final result = AdaptyAttributeConverter.convertToCustomAttributes(attributes);

      expect(result, hasLength(2));
      expect(result.any((attr) => attr['key'] == 'feature_enabled'), isTrue);
      expect(result.any((attr) => attr['key'] == 'valid_field'), isTrue);
      expect(result.any((attr) => attr['key'] == 'feature_expires_at'), isFalse);
      expect(result.any((attr) => attr['key'] == 'created_at'), isFalse);
    });

    test('converts false boolean to string', () {
      final attributes = {'disabled': false};

      final result = AdaptyAttributeConverter.convertToCustomAttributes(attributes);

      expect(result, hasLength(1));
      expect(result[0]['key'], equals('disabled'));
      expect(result[0]['value'], equals('false'));
    });

    test('truncates long keys to 30 characters', () {
      final attributes = {
        'this_is_a_very_long_key_name_that_exceeds_thirty_characters': 'value',
        'short_key': 'value2',
      };

      final result = AdaptyAttributeConverter.convertToCustomAttributes(attributes);

      expect(result, hasLength(2));
      
      final longKeyAttr = result.firstWhere((attr) => 
        attr['key'].toString().startsWith('this_is_a_very_long_key_name_t'));
      expect(longKeyAttr['key'].toString().length, equals(30));
      expect(longKeyAttr['key'], equals('this_is_a_very_long_key_name_t'));
      
      final shortKeyAttr = result.firstWhere((attr) => attr['key'] == 'short_key');
      expect(shortKeyAttr['key'], equals('short_key'));
    });

    test('truncates long string values to 30 characters', () {
      final attributes = {
        'description': 'This is a very long description that definitely exceeds thirty characters',
      };

      final result = AdaptyAttributeConverter.convertToCustomAttributes(attributes);

      expect(result, hasLength(1));
      expect(result[0]['key'], equals('description'));
      expect(result[0]['value'], equals('This is a very long descriptio'));
      expect(result[0]['value'].toString().length, equals(30));
    });

    test('filters out invalid keys', () {
      final attributes = {
        'valid_key': 'value1',
        'invalid key with spaces': 'value2',
        'invalid@key#with\$symbols': 'value3',
        '': 'value4', // empty key
        'valid.key_with-chars123': 'value5',
      };

      final result = AdaptyAttributeConverter.convertToCustomAttributes(attributes);

      expect(result, hasLength(2));
      expect(result.any((attr) => attr['key'] == 'valid_key'), isTrue);
      expect(result.any((attr) => attr['key'] == 'valid.key_with-chars123'), isTrue);
      expect(result.any((attr) => attr['key'] == 'invalid key with spaces'), isFalse);
      expect(result.any((attr) => attr['key'] == 'invalid@key#with\$symbols'), isFalse);
      expect(result.any((attr) => attr['key'] == ''), isFalse);
    });

    test('handles null and empty input', () {
      expect(AdaptyAttributeConverter.convertToCustomAttributes(null), isEmpty);
      expect(AdaptyAttributeConverter.convertToCustomAttributes({}), isEmpty);
    });

    test('converts various number types to double', () {
      final attributes = {
        'int_value': 42,
        'double_value': 3.14,
        'negative_int': -10,
        'zero': 0,
      };

      final result = AdaptyAttributeConverter.convertToCustomAttributes(attributes);

      expect(result, hasLength(4));
      
      for (final attr in result) {
        expect(attr['value'], isA<double>());
      }
      
      expect(result.firstWhere((attr) => attr['key'] == 'int_value')['value'], equals(42.0));
      expect(result.firstWhere((attr) => attr['key'] == 'double_value')['value'], equals(3.14));
      expect(result.firstWhere((attr) => attr['key'] == 'negative_int')['value'], equals(-10.0));
      expect(result.firstWhere((attr) => attr['key'] == 'zero')['value'], equals(0.0));
    });

    test('converts non-string, non-number values to strings', () {
      final attributes = {
        'list_value': [1, 2, 3],
        'object_value': {'nested': 'value'},
      };

      final result = AdaptyAttributeConverter.convertToCustomAttributes(attributes);

      expect(result, hasLength(2));
      
      final listAttr = result.firstWhere((attr) => attr['key'] == 'list_value');
      expect(listAttr['value'], isA<String>());
      expect(listAttr['value'], equals('[1, 2, 3]'));
      
      final objectAttr = result.firstWhere((attr) => attr['key'] == 'object_value');
      expect(objectAttr['value'], isA<String>());
    });

    test('handles null values', () {
      final attributes = {
        'null_value': null,
        'valid_value': 'test',
      };

      final result = AdaptyAttributeConverter.convertToCustomAttributes(attributes);

      expect(result, hasLength(2));
      
      final nullAttr = result.firstWhere((attr) => attr['key'] == 'null_value');
      expect(nullAttr['value'], isNull);
      
      final validAttr = result.firstWhere((attr) => attr['key'] == 'valid_value');
      expect(validAttr['value'], equals('test'));
    });

    test('produces correct Adapty format', () {
      final attributes = {
        'feature_enabled': true,
        'level': 5,
      };

      final result = AdaptyAttributeConverter.convertToCustomAttributes(attributes);

      expect(result, hasLength(2));
      
      // Each item should have 'key' and 'value' fields
      for (final attr in result) {
        expect(attr, containsPair('key', isA<String>()));
        expect(attr, contains('value'));
        expect(attr.keys, hasLength(2));
      }
    });
  });
}