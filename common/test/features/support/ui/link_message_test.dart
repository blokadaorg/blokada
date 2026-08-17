import 'package:common/src/features/support/ui/link_message.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Accent doubles as the sent-bubble background (ColorScheme.primary in
// app.dart), which is exactly the collision these tests guard against.
const _accent = Color(0xffe450ba);
const _onPrimary = Colors.white;

const _blokadaTheme = BlokadaTheme(
  bgColor: Color(0xFFF2F1F6),
  bgColorHome1: Colors.white,
  bgColorHome2: Colors.white,
  bgColorHome3: Colors.white,
  bgColorCard: Colors.white,
  panelBackground: Colors.white,
  cloud: Color(0xFF007AFF),
  accent: _accent,
  freemium: Color(0xFF48A9A6),
  shadow: Color(0xffe8e8e8),
  bgMiniCard: Colors.white,
  textPrimary: Colors.black,
  textSecondary: Colors.black54,
  divider: Colors.black26,
);

Widget _host({required bool sentByMe, TextStyle? sentTextStyle}) {
  final themeData = ThemeData(
    colorScheme: const ColorScheme.light().copyWith(primary: _accent, onPrimary: _onPrimary),
    extensions: const [_blokadaTheme],
  );
  return MaterialApp(
    theme: themeData,
    home: MultiProvider(
      providers: [
        Provider<ChatTheme>.value(value: ChatTheme.fromThemeData(themeData)),
        Provider<UserID>.value(value: 'me'),
      ],
      child: Scaffold(
        body: LinkMessage(
          message: TextMessage(
            id: '1',
            authorId: sentByMe ? 'me' : 'support',
            text: 'write to support@blokada.org please',
          ),
          index: 0,
          onOpenLink: (_) {},
          sentTextStyle: sentTextStyle,
          showTime: false,
          showStatus: false,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('sent-bubble link uses onPrimary, not the bubble color', (tester) async {
    await tester.pumpWidget(_host(sentByMe: true));
    final linkify = tester.widget<Linkify>(find.byType(Linkify));
    expect(linkify.linkStyle?.color, _onPrimary);
    expect(linkify.linkStyle?.color, isNot(_accent));
  });

  testWidgets('sent-bubble link underline matches the link color', (tester) async {
    await tester.pumpWidget(_host(sentByMe: true));
    final linkify = tester.widget<Linkify>(find.byType(Linkify));
    expect(linkify.linkStyle?.decorationColor, linkify.linkStyle?.color);
  });

  testWidgets('sent-bubble link falls back to onPrimary for colorless sentTextStyle', (
    tester,
  ) async {
    await tester.pumpWidget(_host(sentByMe: true, sentTextStyle: const TextStyle(fontSize: 16)));
    final linkify = tester.widget<Linkify>(find.byType(Linkify));
    expect(linkify.linkStyle?.color, _onPrimary);
    expect(linkify.linkStyle?.color, isNot(_accent));
  });

  testWidgets('received-bubble link uses accent', (tester) async {
    await tester.pumpWidget(_host(sentByMe: false));
    final linkify = tester.widget<Linkify>(find.byType(Linkify));
    expect(linkify.linkStyle?.color, _accent);
  });

  testWidgets('received-bubble link underline matches the link color', (tester) async {
    await tester.pumpWidget(_host(sentByMe: false));
    final linkify = tester.widget<Linkify>(find.byType(Linkify));
    expect(linkify.linkStyle?.decorationColor, _accent);
  });
}
