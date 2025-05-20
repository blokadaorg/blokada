import 'package:common/common/module/support/support.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

extension SupportMsgExt on SupportMessage {
  Message toFlyerMessage(User me, User notMe) {
    return TextMessage(
      id: when.millisecondsSinceEpoch.toString(),
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
