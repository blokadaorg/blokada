part of 'payment.dart';

/// Utility class for converting account attributes to Adapty's custom_attributes format.
class AdaptyAttributeConverter {
  /// Converts a map of attributes to Adapty's custom_attributes format.
  /// Returns an array of objects with "key" and "value" fields as expected by Adapty API.
  static List<Map<String, dynamic>> convertToCustomAttributes(
      Map<String, dynamic>? attributes) {
    if (attributes == null || attributes.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final customAttrs = <Map<String, dynamic>>[];

    for (final entry in attributes.entries) {
      // Validate and truncate key to 30 characters
      final processedKey = _validateAndTruncateKey(entry.key);
      if (processedKey.isEmpty) {
        continue; // Skip invalid keys
      }

      // Skip timestamp values as they're not useful for Adapty custom attributes
      if (_shouldSkipValue(entry.value)) {
        continue;
      }

      // Convert value according to Adapty requirements
      final processedValue = _convertValueForAdapty(entry.value);

      customAttrs.add({
        'key': processedKey,
        'value': processedValue,
      });
    }

    return customAttrs;
  }

  /// Validates key format and truncates to 30 characters.
  /// Keys can only contain letters, numbers, dashes, periods, and underscores.
  static String _validateAndTruncateKey(String key) {
    if (key.isEmpty) {
      return '';
    }

    // Check if key contains only valid characters
    final validChars = RegExp(r'^[a-zA-Z0-9\-._]+$');
    if (!validChars.hasMatch(key)) {
      return '';
    }

    // Truncate to 30 characters
    if (key.length > 30) {
      return key.substring(0, 30);
    }
    return key;
  }

  /// Returns true for timestamp values that shouldn't be sent to Adapty.
  static bool _shouldSkipValue(dynamic value) {
    if (value == null) {
      return false;
    }

    // Skip DateTime objects and timestamp strings
    if (value is DateTime) {
      return true;
    }

    // Skip strings that look like ISO timestamps
    if (value is String && _isTimestamp(value)) {
      return true;
    }

    return false;
  }

  /// Checks if a string looks like an ISO timestamp.
  static bool _isTimestamp(String value) {
    try {
      DateTime.parse(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Converts values to Adapty-compatible format.
  static dynamic _convertValueForAdapty(dynamic value) {
    if (value == null) {
      return null;
    }

    switch (value.runtimeType) {
      case bool:
        // Convert boolean to "true"/"false" string for better readability
        return value ? 'true' : 'false';

      case int:
      case double:
        // Convert to double as required by Adapty
        return value.toDouble();

      case String:
        final str = value as String;
        // Truncate string to 30 characters
        if (str.length > 30) {
          return str.substring(0, 30);
        }
        return str;

      default:
        // Convert other types to string and truncate
        final str = value.toString();
        if (str.length > 30) {
          return str.substring(0, 30);
        }
        return str;
    }
  }
}
