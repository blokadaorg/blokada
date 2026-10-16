part of 'support.dart';

enum SupportEvent {
  firstOpen("FIRST_OPEN");

  final String constant;

  const SupportEvent(this.constant);
}

/// Things the app can do on the agent's request, declared when a session
/// starts. The agent asks for one with an action of the same type.
enum SupportClientTool {
  /// Upload the end of the app log from a button in the chat.
  attachLog("attach_log");

  final String constant;

  const SupportClientTool(this.constant);
}

/// The most the support server accepts for one log upload, in bytes.
const supportLogMaxBytes = 1048576;

/// Keeps the log within [maxBytes] of UTF-8, dropping the oldest lines.
///
/// The platform already reads only the end of the file, but replacing invalid
/// bytes while decoding can grow it, and the server refuses an upload over
/// its limit. The cut starts after a newline so the log does not open with
/// half a line.
String capLogTail(String log, int maxBytes) {
  final bytes = utf8.encode(log);
  if (bytes.length <= maxBytes) return log;
  var start = bytes.length - maxBytes;
  // Never start inside a multi-byte character.
  while (start < bytes.length && bytes[start] & 0xC0 == 0x80) {
    start++;
  }
  final newline = bytes.indexOf(0x0A, start - 1);
  if (newline >= 0) start = newline + 1;
  return utf8.decode(bytes.sublist(start));
}

class SupportMessage {
  static int _nextId = 0;

  String text;
  bool isMe;
  DateTime when;

  /// A note in the history that the app log was shared, not a spoken message.
  /// Its text is empty; the chat renders the localized note.
  final bool isLogShared;

  /// A note that the user turned down the agent's log request.
  final bool isLogDeclined;

  // The chat controller rejects duplicate ids, and the timestamp is not
  // unique: a local command and its reply often land in the same millisecond.
  // Not persisted; each loaded message gets a fresh one.
  final String id = "msg-${_nextId++}";

  SupportMessage(this.text, this.when,
      {required this.isMe,
      this.isLogShared = false,
      this.isLogDeclined = false});

  SupportMessage.logShared(this.when)
      : text = "",
        isMe = true,
        isLogShared = true,
        isLogDeclined = false;

  SupportMessage.logDeclined(this.when)
      : text = "",
        isMe = true,
        isLogShared = false,
        isLogDeclined = true;

  SupportMessage.fromJson(Map<String, dynamic> json)
      : text = json['text'],
        isMe = json['is_me'],
        when = DateTime.parse(json['when']),
        isLogShared = json['log_shared'] ?? false,
        isLogDeclined = json['log_declined'] ?? false;

  Map<String, dynamic> toJson() => {
        'text': text,
        'is_me': isMe,
        'when': when.toIso8601String(),
        if (isLogShared) 'log_shared': true,
        if (isLogDeclined) 'log_declined': true,
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
