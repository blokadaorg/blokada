part of 'support.dart';

enum SupportEvent {
  firstOpen("FIRST_OPEN");

  final String constant;

  const SupportEvent(this.constant);
}

class SupportMessage {
  static int _nextId = 0;

  String text;
  bool isMe;
  DateTime when;

  // The chat controller rejects duplicate ids, and the timestamp is not
  // unique: a local command and its reply often land in the same millisecond.
  // Not persisted; each loaded message gets a fresh one.
  final String id = "msg-${_nextId++}";

  SupportMessage(this.text, this.when, {required this.isMe});

  SupportMessage.fromJson(Map<String, dynamic> json)
      : text = json['text'],
        isMe = json['is_me'],
        when = DateTime.parse(json['when']);

  Map<String, dynamic> toJson() => {
        'text': text,
        'is_me': isMe,
        'when': when.toIso8601String(),
      };
}

class SupportMessages {
  final List<SupportMessage> messages;

  SupportMessages(this.messages);

  SupportMessages.fromJson(Map<String, dynamic> json)
      : messages = (json['messages'] as List)
            .map((e) => SupportMessage.fromJson(e))
            .toList();

  Map<String, dynamic> toJson() => {
        'messages': messages.map((e) => e.toJson()).toList(),
      };
}
