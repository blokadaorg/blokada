import 'package:common/src/shared/navigation.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';
import 'golden_tools.dart';

void main() {
  // Dark goldens keep their original names; light ones get a `_light` suffix.
  for (final brightness in Brightness.values) {
    final dark = brightness == Brightness.dark;
    String golden(String name) => dark ? name : '${name}_light';

    group('v6 screens (Android, ${brightness.name})', skip: goldenSkip, () {
      testWidgets('home inactive', (tester) async {
        await bootModules(tester);
        await seedCloudAccount(tester);
        seedAppStatus(AppStatus.deactivated);
        await expectScreen(tester, golden('home_inactive'), brightness: brightness);
      });

      testWidgets('home active', (tester) async {
        await bootModules(tester);
        await seedCloudAccount(tester);
        seedDevice();
        seedStats();
        seedAppStatus(AppStatus.activatedCloud);
        await expectScreen(tester, golden('home_active'), brightness: brightness);
      });

      testWidgets('privacy pulse', (tester) async {
        await bootModules(tester);
        await seedCloudAccount(tester);
        seedDevice();
        seedStats();
        seedAppStatus(AppStatus.activatedCloud);
        await expectScreen(tester, golden('privacy_pulse'),
            path: Paths.privacyPulse, brightness: brightness);
      });

      testWidgets('activity', (tester) async {
        await bootModules(tester);
        await seedCloudAccount(tester);
        seedDevice();
        seedAppStatus(AppStatus.activatedCloud);
        await expectScreen(tester, golden('activity'),
            path: Paths.activity, brightness: brightness);
      });

      testWidgets('advanced', (tester) async {
        await bootModules(tester);
        await seedCloudAccount(tester);
        await seedBlocklists(tester);
        seedAppStatus(AppStatus.activatedCloud);
        await expectScreen(tester, golden('advanced'),
            path: Paths.advanced, brightness: brightness);
      });

      testWidgets('settings', (tester) async {
        await bootModules(tester);
        await seedCloudAccount(tester);
        seedAppStatus(AppStatus.activatedCloud);
        await expectScreen(tester, golden('settings'),
            path: Paths.settings, brightness: brightness);
      });
    });
  }
}
