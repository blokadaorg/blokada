import 'package:common/src/shared/ui/blokada_segmented_control.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('clicks when the user picks another segment, not the same one', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    var value = 'a';
    final picked = <String?>[];
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: StatefulBuilder(
            builder: (context, setState) => BlokadaSegmentedControl<String>(
              groupValue: value,
              onValueChanged: (v) {
                picked.add(v);
                setState(() => value = v!);
              },
              children: const {'a': Text('A'), 'b': Text('B')},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(picked, ['b']);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
  });
}
