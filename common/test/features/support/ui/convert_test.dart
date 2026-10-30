import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/features/support/ui/convert.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const me = User(id: "me");
  const notMe = User(id: "bot");

  test("messages sent in the same millisecond get distinct chat ids", () {
    final when = DateTime(2026, 1, 1, 12);
    final mine = SupportMessage("hi", when, isMe: true);
    final reply = SupportMessage("OK", when, isMe: false);

    expect(mine.toFlyerMessage(me, notMe).id, isNot(reply.toFlyerMessage(me, notMe).id));
  });

  test("a message keeps its chat id across conversions", () {
    final message = SupportMessage("hi", DateTime(2026, 1, 1, 12), isMe: true);

    expect(message.toFlyerMessage(me, notMe).id, message.toFlyerMessage(me, notMe).id);
  });
}
