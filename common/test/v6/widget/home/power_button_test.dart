import 'package:common/src/app_variants/v6/widget/home/power_button.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  group('pauseTimerArcValue', () {
    test('defaults to hidden when no pause is active', () {
      expect(pauseTimerArcValue(AppStatus.initializing, 120), equals(1.0));
      expect(pauseTimerArcValue(AppStatus.deactivated, 0), equals(1.0));
    });

    test('maps remaining pause time to the timer arc', () {
      expect(pauseTimerArcValue(AppStatus.deactivated, 150), equals(0.5));
      expect(pauseTimerArcValue(AppStatus.pausedPlus, 300), equals(0.0));
      expect(pauseTimerArcValue(AppStatus.pausedPlus, 150), equals(0.5));
    });
  });
}
