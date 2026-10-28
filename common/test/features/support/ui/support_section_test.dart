import 'package:common/src/core/core.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/features/support/ui/convert.dart';
import 'package:common/src/features/support/ui/support_action_card.dart';
import 'package:common/src/features/support/ui/support_section.dart';
import 'package:common/src/features/support/ui/support_sheet.dart';
import 'package:common/src/shared/ui/nav_close_button.dart';
import 'package:common/src/features/support/ui/support_typing_bubble.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools.dart';

/// Stands in for the real actor so the test controls when a reply is pending,
/// without a backend or stored session.
class _FakeSupportActor extends SupportActor {
  final sent = <String>[];
  bool pending = false;
  SupportAction? current;
  int approved = 0;

  @override
  bool get replyPending => pending;

  @override
  SupportAction? get action => current;

  void setAction(SupportAction? value) {
    current = value;
    onChange();
  }

  @override
  Future<void> approveAction(Marker m) async {
    approved++;
  }

  @override
  Future<void> declineAction(Marker m) async {
    final tool = current!.tool;
    current = null;
    await controller.insertMessage(
        SupportMessage.note(SupportNote.of(tool, declined: true),
                DateTime(2026, 9, 7, 11))
            .toFlyerMessage(me, notMe));
    onChange();
  }

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

/// Records what the sheet reports, without the persisted flag behind it.
class _FakeSupportUnreadActor extends SupportUnreadActor {
  final events = <String>[];

  @override
  void sheetOpened() => events.add("opened");

  @override
  void sheetClosed() => events.add("closed");
}

IconButton _sendButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

void main() {
  testWidgets("the sheet takes 60% of the screen, closes with × and reports "
      "while it is open", (tester) async {
    await withTrace((_) async {
      Core.register<StageStore>(StageStore());
      Core.register<SupportActor>(_FakeSupportActor());
      final unread = _FakeSupportUnreadActor();
      Core.register<SupportUnreadActor>(unread);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [_lightTheme]),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const SupportSheet(),
              ),
              child: const Text("open"),
            ),
          ),
        ),
      ));
      await tester.tap(find.text("open"));
      await tester.pumpAndSettle();

      expect(unread.events, ["opened"]);
      expect(find.byType(TextField), findsOneWidget);
      final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getSize(find.byType(SupportSheet)).height, screen * 0.6);
      // × is the only action: no way to end the chat.
      expect(find.text("support action end".i18n), findsNothing);

      await tester.tap(find.byType(NavCloseButton));
      await tester.pumpAndSettle();

      expect(find.byType(SupportSheet), findsNothing);
      expect(unread.events, ["opened", "closed"]);
      // Lets the session start debounce run out.
      await tester.pump(const Duration(seconds: 2));
    });
  });

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

        // A history longer than the screen, so the bubble's place matters.
        await actor.controller.insertAllMessages([
          for (var i = 0; i < 30; i++)
            TextMessage(
              id: "$i",
              authorId: i.isEven ? actor.notMe.id : actor.me.id,
              createdAt: DateTime(2026, 9, 7, 12, i),
              text: "message $i",
            ),
        ]);
        await tester.pump(const Duration(milliseconds: 500));

        // Pending: indicator in the chat, send button disabled.
        actor.setPending(true);
        await tester.pump();
        expect(find.byType(SupportTypingBubble), findsOneWidget);
        expect(find.byType(IsTypingIndicator), findsOneWidget);
        // It sits right after the newest message, on screen, not up by the
        // oldest ones.
        final bubble = tester.getRect(find.byType(SupportTypingBubble));
        final newest = tester.getRect(find.text("message 29"));
        expect(bubble.top, greaterThanOrEqualTo(newest.bottom));
        expect(bubble.bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(TextField)).top));

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

  testWidgets("asks before sharing the log, and notes it once shared",
      (tester) async {
    await withTrace((_) async {
      Core.register<StageStore>(StageStore());
      final actor = _FakeSupportActor();
      Core.register<SupportActor>(actor);

      await tester.pumpWidget(_host(dark: false));
      await tester.pump();
      expect(find.byType(SupportActionCard), findsNothing);

      // Both choices are on the card (the test locale shows the keys).
      actor.setAction(const SupportAction(SupportClientTool.attachLog, "act-1"));
      await tester.pump();
      expect(find.text("support share log title"), findsOneWidget);
      expect(find.widgetWithText(TextButton, "universal action cancel"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "universal action share log"), findsOneWidget);

      // Cancel leaves a note, and the agent asking again (same action id)
      // brings the card back.
      final action = actor.action;
      await tester.tap(find.text("universal action cancel"));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SupportActionCard), findsNothing);
      expect(find.text("support share log declined"), findsOneWidget);
      actor.setAction(action);
      await tester.pump();
      expect(find.byType(SupportActionCard), findsOneWidget);

      // While the upload runs the choices are disabled.
      await tester.tap(find.text("universal action share log"));
      await tester.pump();
      expect(actor.approved, 1);
      actor.setPending(true);
      await tester.pump();
      final share = find.widgetWithText(FilledButton, "universal action share log");
      expect(tester.widget<FilledButton>(share).onPressed, isNull);

      // Uploaded: the card gives way to the note in the history.
      await actor.controller.insertMessage(
          SupportMessage.note(SupportNote.logShared, DateTime(2026, 9, 7, 12))
              .toFlyerMessage(actor.me, actor.notMe));
      actor.setPending(false);
      actor.setAction(null);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SupportActionCard), findsNothing);
      expect(find.byType(SupportActionNote), findsNWidgets(2));
      expect(find.text("support share log done"), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  testWidgets("asks before running the DNS check, and notes a cancel",
      (tester) async {
    await withTrace((_) async {
      Core.register<StageStore>(StageStore());
      final actor = _FakeSupportActor();
      Core.register<SupportActor>(actor);

      await tester.pumpWidget(_host(dark: false));
      await tester.pump();

      actor.setAction(const SupportAction(SupportClientTool.dnsCheck, "chk-1",
          subdomain: "k3x9q0b7m2ta"));
      await tester.pump();
      expect(find.text("support network check title"), findsOneWidget);
      expect(find.text("support network check body"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "universal action run check"),
          findsOneWidget);

      await tester.tap(find.text("universal action run check"));
      await tester.pump();
      expect(actor.approved, 1);

      await tester.tap(find.text("universal action cancel"));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SupportActionCard), findsNothing);
      expect(find.text("support network check declined"), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
