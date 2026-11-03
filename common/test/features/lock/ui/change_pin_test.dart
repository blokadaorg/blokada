import 'package:common/src/core/core.dart';
import 'package:common/src/features/lock/domain/lock.dart';
import 'package:common/src/features/lock/ui/change_pin.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';

@GenerateNiceMocks([MockSpec<StageStore>(), MockSpec<Persistence>()])
import 'change_pin_test.mocks.dart';

void _registerDeps() {
  Core.register<StageStore>(MockStageStore());
  final persistence = MockPersistence();
  when(persistence.load(any, any)).thenAnswer((_) => Future.value(null));
  Core.register<Persistence>(persistence);
  Core.register(IsLocked());
  Core.register(HasPin());
  Core.register(ExistingPin());
  Core.register(LockActor());
}

/// A screen with one button that submits [pin], standing in for Settings.
Widget _screen(Marker m, String pin, VoidCallback onAccepted) => MaterialApp(
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
  home: Builder(
    builder: (context) => TextButton(
      onPressed: () => changePin(context, m, pin, onAccepted: onAccepted),
      child: const Text("submit"),
    ),
  ),
);

void main() {
  testWidgets("an invalid PIN shows the error in Flutter and keeps the screen", (tester) async {
    await withTrace((m) async {
      _registerDeps();
      var accepted = false;

      await tester.pumpWidget(_screen(m, "12", () => accepted = true));
      await tester.tap(find.text("submit"));
      await tester.pumpAndSettle();

      expect(find.text("error lock invalid".i18n), findsOneWidget);
      expect(accepted, false);
      expect(Core.get<IsLocked>().now, false);
      verifyNever((Core.get<StageStore>() as MockStageStore).showModal(any, any));
    });
  });

  testWidgets("a valid PIN closes the screen and locks without an error", (tester) async {
    await withTrace((m) async {
      _registerDeps();
      var accepted = false;

      await tester.pumpWidget(_screen(m, "1234", () => accepted = true));
      await tester.tap(find.text("submit"));
      await tester.pumpAndSettle();

      expect(find.text("error lock invalid".i18n), findsNothing);
      expect(accepted, true);
      expect(Core.get<IsLocked>().now, true);
    });
  });
}
