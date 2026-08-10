//
//  Stringjson_builder.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

extension DataTimeJSONBuilder on DateTime {
  static DateTime fromJsonValue(String json) => DateTime.parse(json);

  String toAdaptyValidString() {
    final utcDateTime = toUtc().copyWith(microsecond: 0);
    return utcDateTime.toIso8601String();
  }
}

extension MapExtension on Map<String, dynamic> {
  String string(String key) => this[key] as String;

  String? stringIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return value as String;
  }

  List<String>? stringListIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return (value as List<dynamic>).map((e) => e as String).toList(growable: false);
  }

  bool boolean(String key) => this[key] as bool;

  bool? booleanIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return value as bool;
  }

  int integer(String key) => this[key] as int;

  int? integerIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return value as int;
  }

  double float(String key) => (this[key] as num).toDouble();

  double? floatIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return (value as num).toDouble();
  }

  Map<String, dynamic> object(String key) => this[key] as Map<String, dynamic>;

  Map<String, dynamic>? objectIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return value as Map<String, dynamic>;
  }

  DateTime dateTime(String key) => DataTimeJSONBuilder.fromJsonValue(this[key]);

  DateTime? dateTimeIfPresent(String key) {
    var value = this[key];
    if (value == null) return null;
    return DataTimeJSONBuilder.fromJsonValue(value);
  }
}
