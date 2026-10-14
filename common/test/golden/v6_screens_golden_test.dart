import 'package:common/src/shared/navigation.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';
import 'golden_tools.dart';

void main() {
  group('v6 screens (Android, dark)', () {
    testWidgets('home inactive', (tester) async {
      await bootModules(tester);
      seedCloudAccount();
      seedAppStatus(AppStatus.deactivated);
      await expectScreen(tester, 'home_inactive');
    });

    testWidgets('home active', (tester) async {
      await bootModules(tester);
      seedCloudAccount();
      seedDevice();
      seedStats();
      seedAppStatus(AppStatus.activatedCloud);
      await expectScreen(tester, 'home_active');
    });

    testWidgets('privacy pulse', (tester) async {
      await bootModules(tester);
      seedCloudAccount();
      seedDevice();
      seedStats();
      seedAppStatus(AppStatus.activatedCloud);
      await expectScreen(tester, 'privacy_pulse', path: Paths.privacyPulse);
    });

    testWidgets('advanced', (tester) async {
      await bootModules(tester);
      seedCloudAccount();
      seedAppStatus(AppStatus.activatedCloud);
      await expectScreen(tester, 'advanced', path: Paths.advanced);
    });

    testWidgets('settings', (tester) async {
      await bootModules(tester);
      seedCloudAccount();
      seedAppStatus(AppStatus.activatedCloud);
      await expectScreen(tester, 'settings', path: Paths.settings);
    });
  });
}
