import 'package:common/common/module/support/support.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

extension SupportMsgExt on SupportMessage {
  types.Message toMessage(types.User me, types.User notMe) {
    return types.TextMessage(
      author: isMe ? me : notMe,
      createdAt: when.millisecondsSinceEpoch,
      id: when.millisecondsSinceEpoch.toString(),
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
