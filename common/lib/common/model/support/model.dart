part of '../../model.dart';

enum SupportEvent {
  firstOpen("FIRST_OPEN"),
  purchaseTimeout("PURCHASE_TIMEOUT");

  final String constant;

  const SupportEvent(this.constant);
}

class SupportMessage {
  String text;
  bool isMe;
  DateTime when;

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
