import 'package:common/src/features/support/domain/support.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

extension SupportMsgExt on SupportMessage {
  Message toFlyerMessage(User me, User notMe) {
    if (note != null) {
      return CustomMessage(
        id: id,
        authorId: me.id,
        createdAt: when,
        metadata: {'note': note!.name},
      );
    }
    return TextMessage(
      id: id,
      authorId: isMe ? me.id : notMe.id,
      createdAt: when,
      text: text,
    );
  }
}

// String randomString() {
//   const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
//   final rnd = Random();
//   final result =
//   List.generate(16, (_) => chars[rnd.nextInt(chars.length)]).join();
//   return result;
// }
