import 'dart:async';

import 'package:common/src/platform/app/startup_first_frame_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('org.blokada/startup');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    StartupFirstFrameSignal.debugReset();
  });

  testWidgets('reports the first frame only once across rebuilds', (tester) async {
    var calls = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'firstFrameRendered') {
        calls += 1;
      }
      return null;
    });

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: StartupFirstFrameReporter(
          child: Text('home'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(calls, 1);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: StartupFirstFrameReporter(
          child: Text('home-again'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('renders child immediately while the channel call is still pending', (tester) async {
    final completer = Completer<void>();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'firstFrameRendered') {
        await completer.future;
      }
      return null;
    });

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: StartupFirstFrameReporter(
          child: Text('home'),
        ),
      ),
    );

    expect(find.text('home'), findsOneWidget);

    completer.complete();
    await tester.pump();
    await tester.pump();
  });
}
