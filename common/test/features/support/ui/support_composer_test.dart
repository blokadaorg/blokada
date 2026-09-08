import 'package:common/src/features/support/ui/support_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Hosts the composer with the providers flutter_chat_ui's Chat normally
/// supplies, plus the Stack its Positioned root requires.
Widget _host({required void Function(String) onSend}) {
  final themeData = ThemeData(colorScheme: const ColorScheme.light());
  return MaterialApp(
    theme: themeData,
    home: MultiProvider(
      providers: [
        Provider<ChatTheme>.value(value: ChatTheme.fromThemeData(themeData)),
        Provider<OnMessageSendCallback?>.value(value: onSend),
        Provider<OnAttachmentTapCallback?>.value(value: null),
        ChangeNotifierProvider(create: (_) => ComposerHeightNotifier()),
      ],
      child: const Scaffold(
        body: Stack(children: [SupportComposer()]),
      ),
    ),
  );
}

void main() {
  group("SupportComposer", () {
    testWidgets("asks the keyboard for a send key, not a newline key",
        (tester) async {
      await tester.pumpWidget(_host(onSend: (_) {}));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textInputAction, TextInputAction.send);
      // A multiline keyboard type would make Android IMEs draw a newline key
      // and drop the send action, which is the whole point of the override.
      expect(field.keyboardType, TextInputType.text);
    });

    testWidgets("sends the message on the keyboard's send action",
        (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(_host(onSend: sent.add));

      await tester.enterText(find.byType(TextField), "hello support");
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      expect(sent, ["hello support"]);
    });

    testWidgets("ignores a send action on an empty message", (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(_host(onSend: sent.add));

      await tester.enterText(find.byType(TextField), "   ");
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      expect(sent, isEmpty);
    });
  });
}
