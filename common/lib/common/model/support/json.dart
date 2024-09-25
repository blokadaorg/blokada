part of '../../model.dart';

class JsonSupportPayloadCreateSession {
  late String? message;
  late SupportEvent? event;
  late String language;

  JsonSupportPayloadCreateSession({
    this.message,
    this.event,
    required this.language,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'account_id': ApiParam.accountId.placeholder,
      'user_agent': ApiParam.userAgent.placeholder,
      'message': message,
      'event': event?.constant,
      'language': language,
    };

    if (message == null) {
      json.remove('message');
    }
    if (event == null) {
      json.remove('event');
    }

    return json;
  }
}

class JsonSupportSession {
  late String sessionId;
  late List<JsonSupportHistoryItem> history;
  late String created;
  late int ttl;

  JsonSupportSession({
    required this.sessionId,
    required this.history,
    required this.created,
    required this.ttl,
  });

  JsonSupportSession.fromJson(Map<String, dynamic> json) {
    try {
      sessionId = json['session']['session_id'];
      history = (json['session']['history'] as List)
          .map((e) => JsonSupportHistoryItem.fromJson(e))
          .toList();
      created = json['session']['created'];
      ttl = json['session']['ttl'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonSupportPayloadMessage {
  late String sessionId;
  late String? message;
  late SupportEvent? event;

  JsonSupportPayloadMessage({
    required this.sessionId,
    this.message,
    this.event,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'session_id': sessionId,
      'message': message,
      'event': event?.constant,
    };

    if (message == null) {
      json.remove('message');
    }
    if (event == null) {
      json.remove('event');
    }

    return json;
  }
}

class JsonSupportResponse {
  late List<JsonSupportHistoryItem> messages;

  JsonSupportResponse({
    required this.messages,
  });

  JsonSupportResponse.fromJson(Map<String, dynamic> json) {
    try {
      messages = (json['messages'] as List)
          .map((e) => JsonSupportHistoryItem.fromJson(e))
          .toList();
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonSupportHistoryItem {
  late String? message;
  late String? event;
  late bool isAgent;
  late String timestamp;

  JsonSupportHistoryItem({
    this.message,
    this.event,
    required this.isAgent,
    required this.timestamp,
  });

  JsonSupportHistoryItem.fromJson(Map<String, dynamic> json) {
    try {
      message = (json['content'] as Map<String, dynamic>?)?['message'];
      event = (json['content'] as Map<String, dynamic>?)?['event'];
      isAgent = json['is_agent'];
      timestamp = json['timestamp'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonSupportMarshal {
  JsonSupportSession toSession(JsonString json) {
    return JsonSupportSession.fromJson(jsonDecode(json));
  }

  JsonSupportResponse toResponse(JsonString json) {
    return JsonSupportResponse.fromJson(jsonDecode(json));
  }

  JsonString fromMessage(JsonSupportPayloadMessage message) {
    return jsonEncode(message.toJson());
  }

  JsonString fromCreateSession(JsonSupportPayloadCreateSession payload) {
    return jsonEncode(payload.toJson());
  }
}
