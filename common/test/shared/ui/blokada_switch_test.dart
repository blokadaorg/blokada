import 'package:common/src/shared/ui/blokada_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records haptic calls made through the platform channel.
List<String> _recordHaptics() {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
      return null;
    },
  );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

Widget _on(TargetPlatform platform, Widget child) => MaterialApp(
      theme: ThemeData(platform: platform),
      home: Center(child: child),
    );

void main() {
  for (final (platform, native, other) in [
    (TargetPlatform.android, Switch, CupertinoSwitch),
    (TargetPlatform.iOS, CupertinoSwitch, Switch),
  ]) {
    group('BlokadaSwitch on ${platform.name}', () {
      testWidgets('draws the platform switch with the accent colour', (tester) async {
        await tester.pumpWidget(_on(
          platform,
          BlokadaSwitch(value: true, activeColor: Colors.orange, onChanged: (_) {}),
        ));

        expect(find.byType(native), findsOneWidget);
        expect(find.byType(other), findsNothing);
        final track = platform == TargetPlatform.iOS
            ? tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).activeTrackColor
            : tester.widget<Switch>(find.byType(Switch)).activeTrackColor;
        expect(track, Colors.orange);
      });

      testWidgets('a flip gives a selection click and reports the new value', (tester) async {
        final haptics = _recordHaptics();
        bool? reported;
        await tester.pumpWidget(
            _on(platform, BlokadaSwitch(value: false, onChanged: (v) => reported = v)));

        await tester.tap(find.byType(BlokadaSwitch));
        await tester.pump();

        expect(reported, isTrue);
        expect(haptics, ['HapticFeedbackType.selectionClick']);
      });

      testWidgets('haptic: false leaves the haptic to the caller', (tester) async {
        final haptics = _recordHaptics();
        bool? reported;
        await tester.pumpWidget(_on(
          platform,
          BlokadaSwitch(value: false, haptic: false, onChanged: (v) => reported = v),
        ));

        await tester.tap(find.byType(BlokadaSwitch));
        await tester.pump();

        expect(reported, isTrue);
        expect(haptics, isEmpty);
      });

      testWidgets('a disabled switch does nothing and gives no haptic', (tester) async {
        final haptics = _recordHaptics();
        await tester.pumpWidget(_on(platform, const BlokadaSwitch(value: false, onChanged: null)));

        await tester.tap(find.byType(BlokadaSwitch));
        await tester.pump();

        expect(haptics, isEmpty);
        final enabled = platform == TargetPlatform.iOS
            ? tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).onChanged
            : tester.widget<Switch>(find.byType(Switch)).onChanged;
        expect(enabled, isNull);
      });
    });
  }
}
