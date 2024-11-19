part of 'support.dart';

class CurrentSession extends StringPersistedValue {
  CurrentSession() : super("support_session_id");
}

class ChatHistory extends JsonPersistedValue<SupportMessages> {
  ChatHistory() : super("support_chat_history");

  @override
  SupportMessages fromJson(Map<String, dynamic> json) =>
      SupportMessages.fromJson(json);

  @override
  Map<String, dynamic> toJson(SupportMessages value) => value.toJson();
}

class SupportUnread extends BoolPersistedValue {
  SupportUnread() : super("support_unread");
}
