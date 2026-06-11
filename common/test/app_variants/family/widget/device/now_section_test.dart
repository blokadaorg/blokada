import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/app_variants/family/widget/device/now_section.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tools.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(
        platform: TargetPlatform.iOS,
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

JsonProfile _profile(String id, String name) => JsonProfile(
      profileId: id,
      alias: '$name (parent)',
      lists: const [],
      safeSearch: false,
    );

JsonDevice _device({
  JsonDeviceMode mode = JsonDeviceMode.on,
  DateTime? modeUntil,
  ScheduleModel? schedule,
  String profileId = 'prof_default',
}) {
  final d = JsonDevice(
    deviceTag: 'tag',
    alias: 'Kid Phone',
    mode: mode,
    retention: '24h',
    profileId: profileId,
    modeUntil: modeUntil,
    schedule: schedule,
    timezone: 'Europe/Stockholm',
  );
  d.lastHeartbeat = '2026-05-15T10:00:00Z';
  return d;
}

/// Schedule whose single rule matches any wall-clock minute on any weekday:
/// a [0, 1439) window plus a 1439→1 wrap window covering 23:59 (same trick
/// as schedule_section_test.dart).
ScheduleModel _allDaySchedule() => ScheduleModel(
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

/// NowSection runs a periodic ticker. Pumping an empty tree at the end of a
/// test disposes the section (cancelling the timer) so the framework's
/// "timer still pending" invariant check stays green.
Future<void> _disposeNow(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  final profiles = [_profile('prof_default', 'Standard')];

  testWidgets(
      'default state shows the readout (status + source), the default footer, '
      'and no inline actions', (tester) async {
    await withTrace((_) async {
      await tester.pumpWidget(_wrap(NowSection(
        device: _device(),
        profiles: profiles,
        onOverride: (_, __) {},
        onResume: () {},
      )));
      await tester.pump();

      // Filtering with the default profile, sourced from the device default.
      expect(find.textContaining('family device now status filter'), findsOneWidget);
      expect(find.textContaining('family device now source default'), findsOneWidget);

      // The readout row is the only interactive element; the old inline
      // action rows are gone (they live in the sheet now, which is closed).
      expect(find.byKey(const Key('now_status_row')), findsOneWidget);
      expect(find.byKey(const Key('now_action_block')), findsNothing);
      expect(find.byKey(const Key('now_action_pause')), findsNothing);
      expect(find.byKey(const Key('now_action_resume')), findsNothing);

      // Default-state footer (teaches the tap affordance).
      expect(find.text('family device now footer'), findsOneWidget);
      expect(find.text('family device now footer override'), findsNothing);
      await _disposeNow(tester);
    });
  });

  testWidgets(
      'tapping the readout opens the change-now sheet without Resume when no '
      'override is active; Pause → duration → onOverride(pause, null)', (tester) async {
    await withTrace((_) async {
      OverrideKind? kind;
      DateTime? until;
      var called = false;
      await tester.pumpWidget(_wrap(NowSection(
        device: _device(),
        profiles: profiles,
        onOverride: (k, u) {
          called = true;
          kind = k;
          until = u;
        },
        onResume: () {},
      )));
      await tester.pump();

      await tester.tap(find.byKey(const Key('now_status_row')));
      await tester.pumpAndSettle();

      // Sheet contents: title/brief + the two actions, no Resume.
      expect(find.textContaining('family device now sheet title'), findsOneWidget);
      expect(find.byKey(const Key('now_action_pause')), findsOneWidget);
      expect(find.byKey(const Key('now_action_block')), findsOneWidget);
      expect(find.byKey(const Key('now_action_resume')), findsNothing);

      await tester.tap(find.byKey(const Key('now_action_pause')));
      await tester.pumpAndSettle();

      // Duration sheet (unchanged component).
      expect(find.byKey(const Key('now_duration_hour')), findsOneWidget);
      await tester.tap(find.byKey(const Key('now_duration_indefinite')));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(kind, OverrideKind.pause);
      expect(until, isNull);
      await _disposeNow(tester);
    });
  });

  testWidgets(
      'active indefinite block override: blocked status, indefinite caption, '
      'override footer, and the sheet leads with Resume', (tester) async {
    await withTrace((_) async {
      var resumed = false;
      await tester.pumpWidget(_wrap(NowSection(
        device: _device(mode: JsonDeviceMode.blocked),
        profiles: profiles,
        onOverride: (_, __) {},
        onResume: () => resumed = true,
      )));
      await tester.pump();

      expect(find.text('family device now status blocked'), findsOneWidget);
      expect(find.textContaining('family device now indefinite'), findsOneWidget);
      expect(find.text('family device now footer override'), findsOneWidget);

      await tester.tap(find.byKey(const Key('now_status_row')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('now_action_resume')), findsOneWidget);

      await tester.tap(find.byKey(const Key('now_action_resume')));
      await tester.pumpAndSettle();
      expect(resumed, isTrue);
      await _disposeNow(tester);
    });
  });

  testWidgets('a bounded block override shows a minutes countdown in the readout', (tester) async {
    await withTrace((_) async {
      final until = DateTime.now().add(const Duration(minutes: 30));
      await tester.pumpWidget(_wrap(NowSection(
        device: _device(mode: JsonDeviceMode.blocked, modeUntil: until),
        profiles: profiles,
        onOverride: (_, __) {},
        onResume: () {},
      )));
      await tester.pump();

      expect(find.text('family device now status blocked'), findsOneWidget);
      expect(find.textContaining('family device now until'), findsOneWidget);
      expect(find.textContaining('family device now indefinite'), findsNothing);
      await _disposeNow(tester);
    });
  });

  testWidgets(
      'schedule-sourced state shows the rule profile, the schedule source, '
      'and the window-end caption', (tester) async {
    await withTrace((_) async {
      final schoolProfiles = [
        _profile('prof_default', 'Standard'),
        _profile('prof_school', 'School'),
      ];
      await tester.pumpWidget(_wrap(NowSection(
        device: _device(schedule: _allDaySchedule()),
        profiles: schoolProfiles,
        onOverride: (_, __) {},
        onResume: () {},
      )));
      await tester.pump();

      expect(find.textContaining('family device now status filter'), findsOneWidget);
      // Source caption carries both the schedule attribution and "until".
      expect(find.textContaining('family device now source schedule'), findsOneWidget);
      expect(find.textContaining('family device now until'), findsOneWidget);
      await _disposeNow(tester);
    });
  });

  testWidgets(
      'in-control bar on the readout is red during an override and '
      'transparent otherwise', (tester) async {
    await withTrace((_) async {
      await tester.pumpWidget(_wrap(NowSection(
        device: _device(mode: JsonDeviceMode.blocked),
        profiles: profiles,
        onOverride: (_, __) {},
        onResume: () {},
      )));
      await tester.pump();
      var bar = tester.widget<Container>(find.byKey(const Key('now_status_bar')));
      expect((bar.decoration as BoxDecoration).color, Colors.red);
      await _disposeNow(tester);

      await tester.pumpWidget(_wrap(NowSection(
        device: _device(),
        profiles: profiles,
        onOverride: (_, __) {},
        onResume: () {},
      )));
      await tester.pump();
      bar = tester.widget<Container>(find.byKey(const Key('now_status_bar')));
      expect((bar.decoration as BoxDecoration).color, Colors.transparent);
      await _disposeNow(tester);
    });
  });

  // Regression: the device screen lives on the family shell's *nested*
  // Navigator while both sheets land on the *root* Navigator. The full
  // readout → change-now → duration chain must dismiss only the sheets and
  // keep the device page on screen.
  testWidgets(
      'the readout → sheet → duration chain keeps the device page '
      '(nested-navigator regression)', (tester) async {
    await withTrace((_) async {
      OverrideKind? kind;
      final nestedKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          platform: TargetPlatform.iOS,
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
        home: Navigator(
          key: nestedKey,
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('HOME MARKER')),
            ),
          ),
        ),
      ));
      await tester.pump();

      nestedKey.currentState!.push(MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const Text('DEVICE PAGE MARKER'),
                NowSection(
                  device: _device(),
                  profiles: profiles,
                  onOverride: (k, _) => kind = k,
                  onResume: () {},
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('now_status_row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('now_action_block')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('now_duration_hour')));
      await tester.pumpAndSettle();

      expect(kind, OverrideKind.block);
      expect(find.byKey(const Key('now_duration_hour')), findsNothing);
      expect(find.text('DEVICE PAGE MARKER'), findsOneWidget,
          reason: 'the sheet chain must not pop the device page');
      expect(nestedKey.currentState!.canPop(), isTrue);

      nestedKey.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
