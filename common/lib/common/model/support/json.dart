part of '../../model.dart';

class JsonSupportMessage {
  late String message;

  JsonSupportMessage({
    required this.message,
  });

  JsonSupportMessage.fromJson(Map<String, dynamic> json) {
    try {
      message = json['message'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonSupportPayload {
  // late String userAgent;
  // late String accountId;
  late String sessionId;
  late String language;
  late String? message;
  late SupportEvent? event;

  JsonSupportPayload({
    // required this.userAgent,
    // required this.accountId,
    required this.sessionId,
    required this.language,
    this.message,
    this.event,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'user_agent': ApiParam.userAgent.placeholder,
      'account_id': ApiParam.accountId.placeholder,
      'session_id': sessionId,
      'language': language,
      'message': message,
      'event': event?.constant,
    };
    return json;
  }
}

class JsonSupportMarshal {
  JsonSupportMessage toMessage(JsonString json) {
    return JsonSupportMessage.fromJson(jsonDecode(json));
  }

  JsonString fromPayload(JsonSupportPayload message) {
    return jsonEncode(message.toJson());
  }
}
