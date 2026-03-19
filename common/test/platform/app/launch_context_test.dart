import 'package:common/src/platform/app/launch_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLaunchContext', () {
    test('background task resolves to background bootstrap with source metadata', () {
      final context = AppLaunchContext.fromJson({
        'reason': 'background_task',
        'backgroundSource': 'fcm',
        'fcmEventType': 'weekly_update',
        'payload': '{"type":"weekly_update"}',
      });

      expect(context.reason, LaunchReason.backgroundTask);
      expect(context.profile, BootstrapProfile.background);
      expect(context.allowRunApp, isFalse);
      expect(context.allowForegroundData, isFalse);
      expect(context.allowBackgroundEvents, isTrue);
      expect(context.backgroundSource, BackgroundTaskSource.fcm);
      expect(context.fcmEventType, 'weekly_update');
    });

    test('notification tap resolves to foreground bootstrap metadata', () {
      final context = AppLaunchContext.fromJson({
        'reason': 'notification_tap',
        'notificationId': 'weeklyReport',
      });

      expect(context.reason, LaunchReason.foregroundInteractive);
      expect(context.profile, BootstrapProfile.foreground);
      expect(context.allowRunApp, isTrue);
      expect(context.allowForegroundData, isTrue);
      expect(context.notificationId, 'weeklyReport');
    });

    test('unknown payload falls back to foreground bootstrap', () {
      final context = AppLaunchContext.fromJson(const {});

      expect(context.reason, LaunchReason.foregroundInteractive);
      expect(context.profile, BootstrapProfile.foreground);
      expect(context.allowRunApp, isTrue);
    });
  });
}
