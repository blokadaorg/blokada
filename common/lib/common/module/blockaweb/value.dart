part of 'blockaweb.dart';

// A simple struct provided to blockaweb extension that gives it app status.
class JsonBlockaweb {
  late DateTime accountActiveUntil;
  late bool appActive;

  JsonBlockaweb({
    required this.accountActiveUntil,
    required this.appActive,
  });

  JsonBlockaweb.fromJson(Map<String, dynamic> json) {
    accountActiveUntil =
        DateTime.tryParse(json['accountActiveUntil'] ?? "") ?? DateTime(0);
    appActive = json['appActive'] as bool;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['accountActiveUntil'] = accountActiveUntil.toIso8601String();
    data['appActive'] = appActive;
    return data;
  }
}

class BlockaWebProvidedStatus extends JsonPersistedValue<JsonBlockaweb> {
  BlockaWebProvidedStatus() : super("blockaweb:status");

  @override
  JsonBlockaweb fromJson(Map<String, dynamic> json) =>
      JsonBlockaweb.fromJson(json);

  @override
  Map<String, dynamic> toJson(JsonBlockaweb value) => value.toJson();
}
