part of 'support.dart';

class JsonSupportPayloadCreateSession {
  late String? message;
  late SupportEvent? event;
  late String language;

  /// What the app can do when the agent asks. The server only sends actions
  /// of these types, so an app that cannot handle one never gets it.
  late List<SupportClientTool> clientTools;

  JsonSupportPayloadCreateSession({
    this.message,
    this.event,
    required this.language,
    this.clientTools = const [],
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'account_id': ApiParam.accountId.placeholder,
      'user_agent': ApiParam.userAgent.placeholder,
      'message': message,
      'event': event?.constant,
      'language': language,
      'client_tools': clientTools.map((e) => e.constant).toList(),
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
  late List<JsonSupportHistoryItem>? messages;

  JsonSupportResponse({
    required this.messages,
  });

  JsonSupportResponse.fromJson(Map<String, dynamic> json) {
    try {
      if (json['messages'] == null) {
        messages = null;
        return;
      }

      messages = (json['messages'] as List)
          .map((e) => JsonSupportHistoryItem.fromJson(e))
          .toList();
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonSupportHistoryItem {
  late String? text;
  late String? event;
  late bool isAgent;
  late String timestamp;

  /// What the agent asks the app to offer with this message, such as the
  /// share log button. Only on the last message of an agent reply.
  late List<JsonSupportAction> actions;

  JsonSupportHistoryItem({
    this.text,
    this.event,
    required this.isAgent,
    required this.timestamp,
    this.actions = const [],
  });

  JsonSupportHistoryItem.fromJson(Map<String, dynamic> json) {
    try {
      final content = json['content'] as Map<String, dynamic>?;
      text = content?['text'];
      event = content?['event'];
      // A malformed action, or actions field, is dropped rather than failing the
      // message: it would otherwise fail the whole session load and reset the chat.
      final rawActions = content?['actions'];
      actions = rawActions is List
          ? rawActions
              .whereType<Map<String, dynamic>>()
              .where((e) => e['type'] is String && e['id'] is String)
              .map((e) => JsonSupportAction.fromJson(e))
              .toList()
          : [];
      isAgent = json['is_agent'];
      timestamp = json['timestamp'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

/// A request from the agent for the app to do something, such as offering
/// to upload the app log. [id] names the request when the app answers it.
class JsonSupportAction {
  late String type;
  late String id;

  JsonSupportAction({required this.type, required this.id});

  JsonSupportAction.fromJson(Map<String, dynamic> json) {
    try {
      type = json['type'];
      id = json['id'];
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
