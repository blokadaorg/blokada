import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/widget/home/qr_scan_sheet_macos.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../../tools.dart';

@GenerateNiceMocks([
  MockSpec<LinkActor>(),
])
import 'qr_scan_sheet_macos_test.mocks.dart';

const _validLink =
    "https://go.blokada.org/family/link_device?token=aaa.bbb.ccc";

const _dialogKey = Key('link-confirm-stand-in');

Widget _wrap(GlobalKey<NavigatorState> navKey) => MaterialApp(
      navigatorKey: navKey,
      theme: ThemeData(
        extensions: const [
          BlokadaTheme(
            bgColor: Colors.black,
            bgColorHome1: Colors.black,
            bgColorHome2: Colors.black,
            bgColorHome3: Colors.black,
            bgColorCard: Colors.black,
            panelBackground: Colors.black,
            cloud: Colors.blue,
            accent: Colors.blue,
            freemium: Colors.orange,
            shadow: Colors.black,
            bgMiniCard: Colors.black,
            textPrimary: Colors.white,
            textSecondary: Colors.white70,
            divider: Colors.grey,
          ),
        ],
      ),
      home: const Scaffold(body: SizedBox.shrink()),
    );

// Pushes the sheet the way the home screen does, on top of a base route, so
// the test can tell "the sheet closed" apart from "the navigator emptied".
Future<void> _pushSheet(
    WidgetTester tester, GlobalKey<NavigatorState> navKey) async {
  navKey.currentState!.push(
    MaterialPageRoute(builder: (_) => const QrScanSheetMacos()),
  );
  await tester.pumpAndSettle();
}

// Pumps fixed frames rather than settling: the sheet swaps its buttons for a
// CupertinoActivityIndicator while processing, and that spins forever, so
// pumpAndSettle would time out instead of reporting the assertion that failed.
Future<void> _submit(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('QrScanSheetMacos', () {
    testWidgets('a valid link closes the sheet without closing the '
        'confirmation raised while it commits', (tester) async {
      await withTrace((_) async {
        final navKey = GlobalKey<NavigatorState>();
        final link = MockLinkActor();
        Core.register<LinkActor>(link);
        Core.register<FamilyLinkedMode>(FamilyLinkedMode());

        // Stands in for the home screen, which raises the confirmation as soon
        // as requestLink publishes the pending link. Popping after this point
        // would take the dialog instead of the sheet.
        when(link.requestLink(any, any)).thenAnswer((_) async {
          navKey.currentState!.push(DialogRoute<void>(
            context: navKey.currentContext!,
            builder: (_) => const SizedBox(key: _dialogKey),
          ));
        });

        await tester.pumpWidget(_wrap(navKey));
        await _pushSheet(tester, navKey);
        expect(find.byType(QrScanSheetMacos), findsOneWidget);

        await _submit(tester, _validLink);

        verify(link.requestLink(_validLink, any)).called(1);
        expect(find.byType(QrScanSheetMacos), findsNothing);
        expect(find.byKey(_dialogKey), findsOneWidget);
      });
    });

    testWidgets('a malformed link keeps the sheet open and is never published',
        (tester) async {
      await withTrace((_) async {
        final navKey = GlobalKey<NavigatorState>();
        final link = MockLinkActor();
        Core.register<LinkActor>(link);
        Core.register<FamilyLinkedMode>(FamilyLinkedMode());

        await tester.pumpWidget(_wrap(navKey));
        await _pushSheet(tester, navKey);

        await _submit(tester, "https://example.com/not-a-family-link");

        verifyNever(link.requestLink(any, any));
        expect(find.byType(QrScanSheetMacos), findsOneWidget);
        expect(
          find.text("Invalid link. Please check and try again."),
          findsOneWidget,
        );
      });
    });
  });
}
