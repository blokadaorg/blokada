import 'package:common/src/core/core.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/features/support/ui/ask_support_link.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools.dart';

/// Records what the link asks for, with no backend or stored session.
class _FakeSupportActor extends SupportActor {
  final bool open;
  final calls = <String>[];

  _FakeSupportActor({required this.open});

  @override
  Future<bool> isSessionOpen(Marker m) async => open;

  @override
  Future<void> askSupport(Marker m, SupportEvent event) async {
    calls.add("ask ${event.constant}");
  }
}

const _theme = BlokadaTheme(
  bgColor: Colors.white,
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

Future<_FakeSupportActor> _pump(WidgetTester tester, {required bool open}) async {
  final support = _FakeSupportActor(open: open);
  Core.register<SupportActor>(support);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(extensions: const [_theme]),
    home: Scaffold(
      body: AskSupportLink(
        event: SupportEvent.restoreHelp,
        close: (m) async => support.calls.add("close"),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return support;
}

void main() {
  testWidgets("asks support in grey, closing its screen before the chat opens", (tester) async {
    await withTrace((_) async {
      final support = await _pump(tester, open: false);

      final label = find.text("support action ask".i18n);
      expect(label, findsOneWidget);
      expect(tester.widget<DefaultTextStyle>(find.ancestor(of: label, matching: find.byType(DefaultTextStyle)).first).style.color,
          _theme.textSecondary);

      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(support.calls, ["close", "ask RESTORE_HELP"]);
    });
  });

  testWidgets("reads Continue with support while a chat is open", (tester) async {
    await withTrace((_) async {
      await _pump(tester, open: true);

      expect(find.text("support action continue".i18n), findsOneWidget);
      expect(find.text("support action ask".i18n), findsNothing);
    });
  });
}
