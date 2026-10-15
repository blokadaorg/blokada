import 'package:common/src/shared/navigation.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';
import 'golden_tools.dart';

void main() {
  group('v6 screens (Android, dark)', skip: goldenSkip, () {
    testWidgets('home inactive', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      seedAppStatus(AppStatus.deactivated);
      await expectScreen(tester, 'home_inactive');
    });

    testWidgets('home active', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      seedDevice();
      seedStats();
      seedAppStatus(AppStatus.activatedCloud);
      await expectScreen(tester, 'home_active');
    });

    testWidgets('privacy pulse', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      seedDevice();
      seedStats();
      seedAppStatus(AppStatus.activatedCloud);
      await expectScreen(tester, 'privacy_pulse', path: Paths.privacyPulse);
    });

    testWidgets('activity', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      seedDevice();
      seedAppStatus(AppStatus.activatedCloud);
      await expectScreen(tester, 'activity', path: Paths.activity);
    });

    testWidgets('advanced', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      seedAppStatus(AppStatus.activatedCloud);
      await expectScreen(tester, 'advanced', path: Paths.advanced);
    });

    testWidgets('settings', (tester) async {
      await bootModules(tester);
      await seedCloudAccount(tester);
      seedAppStatus(AppStatus.activatedCloud);
      await expectScreen(tester, 'settings', path: Paths.settings);
    });
  });
}
