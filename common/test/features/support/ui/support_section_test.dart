import 'package:common/src/core/core.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/features/support/ui/support_section.dart';
import 'package:common/src/features/support/ui/support_typing_bubble.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools.dart';

/// Stands in for the real actor so the test controls when a reply is pending,
/// without a backend or stored session.
class _FakeSupportActor extends SupportActor {
  final sent = <String>[];
  bool pending = false;

  @override
  bool get replyPending => pending;

  void setPending(bool value) {
    pending = value;
    onChange();
  }

  @override
  Future<bool> loadOrInit(Marker m, {SupportEvent? event}) async => false;

  @override
  maybeStartSession(Marker m) async {}

  @override
  sendMessage(String? message, Marker m, {bool retrying = false}) async {
    sent.add(message!);
  }
}

const _lightTheme = BlokadaTheme(
  bgColor: Color(0xFFF2F1F6),
  bgColorHome1: Colors.white,
  bgColorHome2: Colors.white,
  bgColorHome3: Colors.white,
  bgColorCard: Colors.white,
  panelBackground: Colors.white,
  cloud: Color(0xFF007AFF),
  accent: Color(0xffe450ba),
  freemium: Color(0xFF48A9A6),
  shadow: Color(0xffe8e8e8),
  bgMiniCard: Colors.white,
  textPrimary: Colors.black,
  textSecondary: Colors.black54,
  divider: Colors.black26,
);

const _darkTheme = BlokadaTheme(
  bgColor: Colors.black,
  bgColorHome1: Color(0xFF1C1C1E),
  bgColorHome2: Color(0xFF1C1C1E),
  bgColorHome3: Color(0xFF1C1C1E),
  bgColorCard: Color(0xFF1C1C1E),
  panelBackground: Color(0xFF1C1C1E),
  cloud: Color(0xFF0A84FF),
  accent: Color(0xffe450ba),
  freemium: Color(0xFF48A9A6),
  shadow: Color(0xFF1C1C1E),
  bgMiniCard: Color(0xFF1C1C1E),
  textPrimary: Colors.white,
  textSecondary: Colors.white70,
  divider: Colors.white24,
);

Widget _host({required bool dark}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: dark ? const ColorScheme.dark() : const ColorScheme.light(),
      extensions: [dark ? _darkTheme : _lightTheme],
    ),
    home: const Scaffold(body: SupportSection()),
  );
}

IconButton _sendButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? "dark" : "light";

    testWidgets("shows typing and blocks sending while a reply is pending "
        "($mode)", (tester) async {
      await withTrace((_) async {
        Core.register<StageStore>(StageStore());
        final actor = _FakeSupportActor();
        Core.register<SupportActor>(actor);

        await tester.pumpWidget(_host(dark: dark));
        await tester.pump();

        // Idle: no indicator, and typed text can be sent.
        expect(find.byType(SupportTypingBubble), findsNothing);
        await tester.enterText(find.byType(TextField), "first");
        await tester.pump();
        expect(_sendButton(tester).onPressed, isNotNull);
        await tester.tap(find.widgetWithIcon(IconButton, Icons.send));
        await tester.pump();
        expect(actor.sent, ["first"]);
        expect(find.text("first"), findsNothing,
            reason: "an accepted send clears the field");

        // Pending: indicator in the chat, send button disabled.
        actor.setPending(true);
        await tester.pump();
        expect(find.byType(SupportTypingBubble), findsOneWidget);
        expect(find.byType(IsTypingIndicator), findsOneWidget);

        await tester.enterText(find.byType(TextField), "second");
        await tester.pump();
        expect(_sendButton(tester).onPressed, isNull);

        // The keyboard's send action skips the button: it must be refused
        // too, keeping the text for later.
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump();
        expect(actor.sent, ["first"]);
        expect(find.text("second"), findsOneWidget);

        // Reply (or error message) in: indicator gone, sending works again.
        actor.setPending(false);
        await tester.pump();
        expect(find.byType(SupportTypingBubble), findsNothing);
        expect(_sendButton(tester).onPressed, isNotNull);
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump();
        expect(actor.sent, ["first", "second"]);

        // Let the session-start debounce fire before teardown.
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    });
  }
}
