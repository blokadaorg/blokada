part of 'rate.dart';

class RateMetadataValue extends JsonPersistedValue<JsonRate> {
  RateMetadataValue() : super("rate:metadata");

  @override
  JsonRate fromJson(Map<String, dynamic> json) => JsonRate.fromJson(json);

  @override
  Map<String, dynamic> toJson(JsonRate value) => value.toJson();
}
