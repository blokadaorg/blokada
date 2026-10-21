import 'package:common/src/features/home/domain/power.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:flutter_test/flutter_test.dart';

PowerButtonState _state(AppStatus status, {bool isFreemium = false, int pauseSecondsLeft = 0}) =>
    powerButtonState(status: status, isFreemium: isFreemium, pauseSecondsLeft: pauseSecondsLeft);

const _working = PowerButtonState(
  working: true,
  active: false,
  plus: false,
  freemium: false,
  pauseSecondsLeft: null,
  tap: PowerTap.none,
  longTap: PowerTap.none,
);

const _off = PowerButtonState(
  working: false,
  active: false,
  plus: false,
  freemium: false,
  pauseSecondsLeft: null,
  tap: PowerTap.toggle,
  longTap: PowerTap.toggle,
);

const _on = PowerButtonState(
  working: false,
  active: true,
  plus: false,
  freemium: false,
  pauseSecondsLeft: null,
  tap: PowerTap.pauseSheet,
  longTap: PowerTap.toggle,
);

void main() {
  group('powerButtonState', () {
    test('unknown is working and ignores taps', () {
      expect(_state(AppStatus.unknown), _working);
    });

    test('initializing is working and ignores taps', () {
      expect(_state(AppStatus.initializing), _working);
    });

    test('reconfiguring is working and ignores taps', () {
      expect(_state(AppStatus.reconfiguring), _working);
    });

    test('initFail is off and a tap retries', () {
      expect(_state(AppStatus.initFail), _off);
    });

    test('deactivated is off and a tap switches on', () {
      expect(_state(AppStatus.deactivated), _off);
    });

    test('paused is off and a tap switches on', () {
      expect(_state(AppStatus.paused), _off);
    });

    test('pausedPlus is off and a tap switches on', () {
      expect(_state(AppStatus.pausedPlus), _off);
    });

    test('activatedCloud is on (blue) and a tap opens the pause sheet', () {
      expect(_state(AppStatus.activatedCloud), _on);
    });

    test('activatedPlus is on with the orange ring and a tap opens the pause sheet', () {
      expect(
        _state(AppStatus.activatedPlus),
        const PowerButtonState(
          working: false,
          active: true,
          plus: true,
          freemium: false,
          pauseSecondsLeft: null,
          tap: PowerTap.pauseSheet,
          longTap: PowerTap.toggle,
        ),
      );
    });

    test('activatedFreemium is on with freemium colours and a tap toggles off', () {
      expect(
        _state(AppStatus.activatedFreemium, isFreemium: true),
        const PowerButtonState(
          working: false,
          active: true,
          plus: false,
          freemium: true,
          pauseSecondsLeft: null,
          tap: PowerTap.toggle,
          longTap: PowerTap.toggle,
        ),
      );
    });

    test('covers every status', () {
      // A new status must get a mapping test above.
      expect(AppStatus.values, hasLength(10));
    });

    test('a timed pause shows the countdown', () {
      final state = _state(AppStatus.paused, pauseSecondsLeft: 150);
      expect(state.pauseSecondsLeft, 150);
      expect(state.pauseArc, 0.5);
      expect(state.tap, PowerTap.toggle);
    });

    test('freemium off still toggles', () {
      expect(_state(AppStatus.deactivated, isFreemium: true).tap, PowerTap.toggle);
    });

    test('pressed while on or working, inactive only when settled off', () {
      expect(_state(AppStatus.activatedCloud).pressed, isTrue);
      expect(_state(AppStatus.reconfiguring).pressed, isTrue);
      expect(_state(AppStatus.reconfiguring).inactive, isFalse);
      expect(_state(AppStatus.deactivated).pressed, isFalse);
      expect(_state(AppStatus.deactivated).inactive, isTrue);
    });
  });

  group('shouldShowPauseTimer', () {
    test('hides timer while app is still initializing', () {
      expect(shouldShowPauseTimer(AppStatus.initializing, 120), isFalse);
    });

    test('shows timer for paused states with time remaining', () {
      expect(shouldShowPauseTimer(AppStatus.deactivated, 120), isTrue);
      expect(shouldShowPauseTimer(AppStatus.pausedPlus, 120), isTrue);
    });

    test('hides timer when pause has expired', () {
      expect(shouldShowPauseTimer(AppStatus.deactivated, 0), isFalse);
      expect(shouldShowPauseTimer(AppStatus.pausedPlus, 0), isFalse);
    });
  });

  group('pause arc', () {
    test('defaults to hidden when no pause is active', () {
      expect(_state(AppStatus.initializing, pauseSecondsLeft: 120).pauseArc, equals(1.0));
      expect(_state(AppStatus.deactivated).pauseArc, equals(1.0));
    });

    test('maps remaining pause time to the timer arc', () {
      expect(_state(AppStatus.deactivated, pauseSecondsLeft: 150).pauseArc, equals(0.5));
      expect(_state(AppStatus.pausedPlus, pauseSecondsLeft: 300).pauseArc, equals(0.0));
      expect(_state(AppStatus.pausedPlus, pauseSecondsLeft: 150).pauseArc, equals(0.5));
    });
  });
}
