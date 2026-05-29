import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/app_variants/family/widget/device/schedule_section.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tools.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(
        extensions: const [
          BlokadaTheme(
            bgColor: Colors.black,
            bgColorHome1: Colors.black,
            bgColorHome2: Colors.black,
            bgColorHome3: Colors.black,
            bgColorCard: Colors.black,
            panelBackground: Colors.black,
            cloud: Colors.blue,
            accent: Colors.blue,
            freemium: Colors.orange,
            shadow: Colors.black,
            bgMiniCard: Colors.black,
            textPrimary: Colors.white,
            textSecondary: Colors.white70,
            divider: Colors.grey,
          ),
        ],
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

JsonProfile _profile(String id, String name) {
  return JsonProfile(
    profileId: id,
    alias: '$name (parent)',
    lists: const [],
    safeSearch: false,
  );
}

void main() {
  final profiles = [
    _profile('prof_default', 'Parent'),
    _profile('prof_school', 'School'),
  ];

  testWidgets(
      'renders Default row (from device profile_id) + rule rows + Add rule',
      (tester) async {
    await withTrace((_) async {
      final schedule = ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: 'prof_school',
            weekdays: const [1, 2, 3, 4, 5],
            windows: const [
              TimeWindowModel(startMinute: 480, endMinute: 900),
            ],
          ),
        ],
      );

      await tester.pumpWidget(_wrap(ScheduleSection(
        deviceTag: 'tag1',
        profiles: profiles,
        defaultProfileId: 'prof_default',
        schedule: schedule,
        onPausedChanged: (_) {},
        onDefaultTap: () {},
        onRuleTap: (_) {},
        onAddRule: () {},
        onReorder: (_, __) {},
      )));
      await tester.pump();

      // Default row uses the locked English label key (test env doesn't
      // resolve translations; key is the source-of-truth value).
      expect(find.text('family schedule default row title'), findsOneWidget);
      // Default profile name comes from JsonProfile.displayAlias = "Parent".
      expect(find.text('Parent'), findsOneWidget);

      // Rule row: profile name + days summary + windows summary. The days
      // summary goes through the i18n key surface so non-English locales
      // pick up their own translation; in the test env the key resolves
      // verbatim.
      expect(find.textContaining('School'), findsWidgets);
      expect(
          find.textContaining('family schedule days summary weekdays'),
          findsOneWidget);
      expect(find.textContaining('08:00–15:00'), findsOneWidget);

      // Add-rule trailing item.
      expect(find.text('family schedule add rule'), findsOneWidget);
    });
  });

  testWidgets(
      'Use-schedule toggle reflects the inverse of paused and invokes the '
      'callback with the inverted new value', (tester) async {
    await withTrace((_) async {
      // Initial schedule active (paused:false): Switch should render ON.
      bool? newPaused;
      await tester.pumpWidget(_wrap(ScheduleSection(
        deviceTag: 'tag1',
        profiles: profiles,
        defaultProfileId: 'prof_default',
        schedule: const ScheduleModel(paused: false, rules: <RuleModel>[]),
        onPausedChanged: (v) => newPaused = v,
        onDefaultTap: () {},
        onRuleTap: (_) {},
        onAddRule: () {},
        onReorder: (_, __) {},
      )));
      await tester.pump();

      final firstSwitch = tester
          .widget<Switch>(find.byKey(const Key('schedule_paused_switch')));
      expect(firstSwitch.value, isTrue,
          reason: 'paused:false should render the toggle as ON.');

      await tester.tap(find.byKey(const Key('schedule_paused_switch')));
      await tester.pump();
      expect(newPaused, isTrue,
          reason: 'Tapping ON → OFF should fire onPausedChanged(true).');

      // Now flip the underlying state: paused:true → Switch should render
      // OFF, and tapping should fire onPausedChanged(false).
      newPaused = null;
      await tester.pumpWidget(_wrap(ScheduleSection(
        deviceTag: 'tag1',
        profiles: profiles,
        defaultProfileId: 'prof_default',
        schedule: const ScheduleModel(paused: true, rules: <RuleModel>[]),
        onPausedChanged: (v) => newPaused = v,
        onDefaultTap: () {},
        onRuleTap: (_) {},
        onAddRule: () {},
        onReorder: (_, __) {},
      )));
      await tester.pump();

      final secondSwitch = tester
          .widget<Switch>(find.byKey(const Key('schedule_paused_switch')));
      expect(secondSwitch.value, isFalse,
          reason: 'paused:true should render the toggle as OFF.');

      await tester.tap(find.byKey(const Key('schedule_paused_switch')));
      await tester.pump();
      expect(newPaused, isFalse,
          reason: 'Tapping OFF → ON should fire onPausedChanged(false).');
    });
  });
}
