import 'dart:async';

import 'package:common/modules.dart';
import 'package:common/src/platform/app/launch_context.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tools.dart';

void main() {
  group('Modules', () {
    test('background start only runs core bootstrap and command acceptance', () async {
      await withTrace((m) async {
        final calls = <String>[];
        final modules = Modules(
          startCoreBootstrap: (marker, launchContext) async {
            calls.add('core:${launchContext.profile.name}');
          },
          acceptCommands: (marker) async {
            calls.add('accept');
          },
          startForegroundPhase: (marker) async {
            calls.add('foreground');
          },
        );

        await modules.start(
          m,
          launchContext: const AppLaunchContext(
            reason: LaunchReason.backgroundTask,
            profile: BootstrapProfile.background,
          ),
        );

        expect(calls, ['core:background', 'accept']);
        expect(modules.foregroundStarted, isFalse);
        expect(modules.foregroundStartInFlight, isFalse);
      });
    });

    test('foreground start defers the foreground phase until requested', () async {
      await withTrace((m) async {
        final calls = <String>[];
        final modules = Modules(
          startCoreBootstrap: (marker, launchContext) async {
            calls.add('core:${launchContext.profile.name}');
          },
          acceptCommands: (marker) async {
            calls.add('accept');
          },
          startForegroundPhase: (marker) async {
            calls.add('foreground');
          },
        );

        await modules.start(
          m,
          launchContext: AppLaunchContext.foregroundInteractive,
        );

        expect(calls, ['core:foreground', 'accept']);
        expect(modules.foregroundStarted, isFalse);
        expect(modules.foregroundStartInFlight, isFalse);

        await modules.startForeground(m);

        expect(calls, ['core:foreground', 'accept', 'foreground']);
        expect(modules.foregroundStarted, isTrue);
        expect(modules.foregroundStartInFlight, isFalse);
      });
    });

    test('startForeground is idempotent while in flight and after completion', () async {
      await withTrace((m) async {
        final completer = Completer<void>();
        var startCalls = 0;
        final modules = Modules(
          startForegroundPhase: (marker) {
            startCalls += 1;
            return completer.future;
          },
        );

        final first = modules.startForeground(m);
        final second = modules.startForeground(m);

        expect(startCalls, 1);
        expect(modules.foregroundStarted, isFalse);
        expect(modules.foregroundStartInFlight, isTrue);

        completer.complete();
        await Future.wait([first, second]);

        expect(modules.foregroundStarted, isTrue);
        expect(modules.foregroundStartInFlight, isFalse);

        await modules.startForeground(m);
        expect(startCalls, 1);
      });
    });
  });
}
