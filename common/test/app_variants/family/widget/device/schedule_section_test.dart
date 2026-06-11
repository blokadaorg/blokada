import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/app_variants/family/widget/device/schedule_section.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
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
      'renders rule rows + Add rule; the Default row is gone (it moved to '
      'Device settings)', (tester) async {
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
        schedule: schedule,
        onPausedChanged: (_) {},
        onRuleTap: (_) {},
        onAddRule: () {},
        onReorder: (_, __) {},
      )));
      await tester.pump();

      // The device's base profile moved to the Device-settings card, so the
      // schedule section no longer renders a Default row.
      expect(find.text('family schedule default row title'), findsNothing);

      // Rule row: profile name + days summary + windows summary. The days
      // summary goes through the i18n key surface so non-English locales
      // pick up their own translation; in the test env the key resolves
      // verbatim.
      expect(find.textContaining('School'), findsWidgets);
      expect(find.textContaining('family schedule days summary weekdays'), findsOneWidget);
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
        schedule: const ScheduleModel(paused: false, rules: <RuleModel>[]),
        onPausedChanged: (v) => newPaused = v,
        onRuleTap: (_) {},
        onAddRule: () {},
        onReorder: (_, __) {},
      )));
      await tester.pump();

      final firstSwitch =
          tester.widget<CupertinoSwitch>(find.byKey(const Key('schedule_paused_switch')));
      expect(firstSwitch.value, isTrue, reason: 'paused:false should render the toggle as ON.');

      await tester.tap(find.byKey(const Key('schedule_paused_switch')));
      await tester.pump();
      expect(newPaused, isTrue, reason: 'Tapping ON → OFF should fire onPausedChanged(true).');

      // Now flip the underlying state: paused:true → Switch should render
      // OFF, and tapping should fire onPausedChanged(false).
      newPaused = null;
      await tester.pumpWidget(_wrap(ScheduleSection(
        deviceTag: 'tag1',
        profiles: profiles,
        schedule: const ScheduleModel(paused: true, rules: <RuleModel>[]),
        onPausedChanged: (v) => newPaused = v,
        onRuleTap: (_) {},
        onAddRule: () {},
        onReorder: (_, __) {},
      )));
      await tester.pump();

      final secondSwitch =
          tester.widget<CupertinoSwitch>(find.byKey(const Key('schedule_paused_switch')));
      expect(secondSwitch.value, isFalse, reason: 'paused:true should render the toggle as OFF.');

      await tester.tap(find.byKey(const Key('schedule_paused_switch')));
      await tester.pump();
      expect(newPaused, isFalse, reason: 'Tapping OFF → ON should fire onPausedChanged(false).');
    });
  });

  testWidgets(
      'marks the firing rule with the Active-now caption, and not '
      'when paused', (tester) async {
    await withTrace((_) async {
      // A rule active at every instant: all weekdays, plus two windows that
      // together cover all 1440 minutes (the wrap window picks up the single
      // minute the [0,1439) window misses), so the marker assertion never
      // flakes on the wall clock.
      ScheduleModel always({required bool paused}) => ScheduleModel(
            paused: paused,
            rules: [
              RuleModel(
                profileId: 'prof_school',
                weekdays: const [1, 2, 3, 4, 5, 6, 7],
                windows: const [
                  TimeWindowModel(startMinute: 0, endMinute: 1439),
                  TimeWindowModel(startMinute: 1439, endMinute: 1),
                ],
              ),
            ],
          );

      ScheduleSection section(ScheduleModel s) => ScheduleSection(
            deviceTag: 'tag1',
            profiles: profiles,
            schedule: s,
            onPausedChanged: (_) {},
            onRuleTap: (_) {},
            onAddRule: () {},
            onReorder: (_, __) {},
          );

      // Active: the firing rule shows the Active-now caption (i18n key
      // resolves verbatim in the test env).
      await tester.pumpWidget(_wrap(section(always(paused: false))));
      await tester.pump();
      expect(find.textContaining('family schedule active now'), findsOneWidget);

      // Paused: the resolver returns null, so no caption renders.
      await tester.pumpWidget(_wrap(section(always(paused: true))));
      await tester.pump();
      expect(find.textContaining('family schedule active now'), findsNothing);
    });
  });

  testWidgets(
      'suppresses the Active-now marker while a manual override is in effect '
      '(the in-control bar lives on the Now readout instead)', (tester) async {
    await withTrace((_) async {
      // A rule firing at every instant — but an override outranks it, so the
      // marker must be withheld to keep exactly one in-control bar on screen.
      final always = ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: 'prof_school',
            weekdays: const [1, 2, 3, 4, 5, 6, 7],
            windows: const [
              TimeWindowModel(startMinute: 0, endMinute: 1439),
              TimeWindowModel(startMinute: 1439, endMinute: 1),
            ],
          ),
        ],
      );

      await tester.pumpWidget(_wrap(ScheduleSection(
        deviceTag: 'tag1',
        profiles: profiles,
        schedule: always,
        overridden: true,
        onPausedChanged: (_) {},
        onRuleTap: (_) {},
        onAddRule: () {},
        onReorder: (_, __) {},
      )));
      await tester.pump();

      // The rule row still renders (and stays editable)…
      expect(find.textContaining('School'), findsWidgets);
      // …but its Active-now marker is suppressed while overridden.
      expect(find.textContaining('family schedule active now'), findsNothing);
    });
  });

  testWidgets('a block rule renders the "No internet" label and no profile name', (tester) async {
    await withTrace((_) async {
      final schedule = ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: '',
            weekdays: const [1, 2, 3, 4, 5, 6, 7],
            windows: const [
              TimeWindowModel(startMinute: 1260, endMinute: 420),
            ],
            action: 'block',
          ),
        ],
      );

      await tester.pumpWidget(_wrap(ScheduleSection(
        deviceTag: 'tag1',
        profiles: profiles,
        schedule: schedule,
        onPausedChanged: (_) {},
        onRuleTap: (_) {},
        onAddRule: () {},
        onReorder: (_, __) {},
      )));
      await tester.pump();

      // Block rules render the neutral "No internet" label (i18n key resolves
      // verbatim in the test env), not a profile name.
      expect(find.textContaining('family schedule rule block title'), findsOneWidget);
      // It still shows the days + times summary.
      expect(find.textContaining('family schedule days summary every'), findsOneWidget);
      expect(find.textContaining('21:00–07:00'), findsOneWidget);
    });
  });
}
