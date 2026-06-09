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

/// NowSection runs a 1-second `Timer.periodic` for its countdown. Pumping an
/// empty tree at the end of a test disposes the section (cancelling the timer)
/// so the framework's "timer still pending" invariant check stays green.
Future<void> _disposeNow(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  final profiles = [_profile('prof_default', 'Standard')];

  testWidgets(
      'default state shows the filtering status, the two override actions, and '
      'the precedence footer', (tester) async {
    await withTrace((_) async {
      await tester.pumpWidget(_wrap(NowSection(
        device: _device(),
        profiles: profiles,
        onOverride: (_, __) {},
        onResume: () {},
      )));
      await tester.pump();

      // Filtering with the default profile, sourced from the device default.
      expect(find.textContaining('family device now status filter'),
          findsOneWidget);
      expect(find.text('family device now source default'), findsOneWidget);

      // Both override actions present; no Resume row (no override active).
      expect(find.byKey(const Key('now_action_block')), findsOneWidget);
      expect(find.byKey(const Key('now_action_pause')), findsOneWidget);
      expect(find.byKey(const Key('now_action_resume')), findsNothing);

      // Precedence footer.
      expect(find.text('family device now footer'), findsOneWidget);
      await _disposeNow(tester);
    });
  });

  testWidgets(
      'active indefinite block override shows the blocked status, the '
      '"until you turn it back on" caption, and the Resume action',
      (tester) async {
    await withTrace((_) async {
      await tester.pumpWidget(_wrap(NowSection(
        device: _device(mode: JsonDeviceMode.blocked),
        profiles: profiles,
        onOverride: (_, __) {},
        onResume: () {},
      )));
      await tester.pump();

      expect(find.text('family device now status blocked'), findsOneWidget);
      expect(find.textContaining('family device now indefinite'),
          findsOneWidget);

      // Resume replaces the override actions while an override is active.
      expect(find.byKey(const Key('now_action_resume')), findsOneWidget);
      expect(find.byKey(const Key('now_action_block')), findsNothing);
      expect(find.byKey(const Key('now_action_pause')), findsNothing);
      await _disposeNow(tester);
    });
  });

  testWidgets(
      'a bounded block override shows a minutes countdown and the Resume '
      'action', (tester) async {
    await withTrace((_) async {
      // 30 minutes out → "30 min" countdown (under an hour renders minutes).
      final until = DateTime.now().add(const Duration(minutes: 30));
      await tester.pumpWidget(_wrap(NowSection(
        device: _device(mode: JsonDeviceMode.blocked, modeUntil: until),
        profiles: profiles,
        onOverride: (_, __) {},
        onResume: () {},
      )));
      await tester.pump();

      expect(find.text('family device now status blocked'), findsOneWidget);
      // Bounded override → the "until %s" caption is shown (the %s param is
      // not interpolated in the no-translation test env, so assert on the
      // key), not the indefinite label.
      expect(find.textContaining('family device now until'), findsOneWidget);
      expect(find.textContaining('family device now indefinite'), findsNothing);
      expect(find.byKey(const Key('now_action_resume')), findsOneWidget);

      await _disposeNow(tester);
    });
  });

  testWidgets('Resume action invokes onResume', (tester) async {
    await withTrace((_) async {
      var resumed = false;
      await tester.pumpWidget(_wrap(NowSection(
        device: _device(mode: JsonDeviceMode.blocked),
        profiles: profiles,
        onOverride: (_, __) {},
        onResume: () => resumed = true,
      )));
      await tester.pump();

      await tester.tap(find.byKey(const Key('now_action_resume')));
      await tester.pumpAndSettle();
      expect(resumed, isTrue);
      await _disposeNow(tester);
    });
  });

  testWidgets(
      'Block action opens the duration sheet; picking "For 1 hour" calls '
      'onOverride(block, ~now+1h)', (tester) async {
    await withTrace((_) async {
      OverrideKind? kind;
      DateTime? until;
      await tester.pumpWidget(_wrap(NowSection(
        device: _device(),
        profiles: profiles,
        onOverride: (k, u) {
          kind = k;
          until = u;
        },
        onResume: () {},
      )));
      await tester.pump();

      await tester.tap(find.byKey(const Key('now_action_block')));
      await tester.pumpAndSettle();

      // The three required choices plus a cancel.
      expect(find.byKey(const Key('now_duration_hour')), findsOneWidget);
      expect(find.byKey(const Key('now_duration_morning')), findsOneWidget);
      expect(find.byKey(const Key('now_duration_indefinite')), findsOneWidget);

      final before = DateTime.now().add(const Duration(hours: 1));
      await tester.tap(find.byKey(const Key('now_duration_hour')));
      await tester.pumpAndSettle();
      final after = DateTime.now().add(const Duration(hours: 1));

      expect(kind, OverrideKind.block);
      expect(until, isNotNull);
      // Within the (before, after) window the sheet captured "now + 1h".
      expect(until!.isAfter(before.subtract(const Duration(seconds: 2))),
          isTrue);
      expect(until!.isBefore(after.add(const Duration(seconds: 2))), isTrue);
      await _disposeNow(tester);
    });
  });

  testWidgets(
      'Pause action "Until I turn it back on" calls onOverride(pause, null)',
      (tester) async {
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

      await tester.tap(find.byKey(const Key('now_action_pause')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('now_duration_indefinite')));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(kind, OverrideKind.pause);
      expect(until, isNull);
      await _disposeNow(tester);
    });
  });

  // Regression for the reported nav bug: the device screen lives on the family
  // shell's *nested* Navigator, but the duration action sheet (via
  // showCupertinoModalPopup) lands on the *root* Navigator. Picking a duration
  // must dismiss only that sheet and keep the device page on screen. The old
  // code popped via the page `context`, which resolved to the nested Navigator
  // and tore the device page down (bouncing to "Home") while the sheet stayed
  // dangling on the root Navigator.
  testWidgets(
      'picking a duration dismisses only the sheet and keeps the device page '
      '(nested-navigator regression)', (tester) async {
    await withTrace((_) async {
      OverrideKind? kind;
      final nestedKey = GlobalKey<NavigatorState>();
      // Root MaterialApp whose home hosts a *nested* Navigator. The device page
      // is pushed onto that nested Navigator, reproducing FamilyMainScreen.
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

      // Push the device page onto the nested Navigator (as Navigation.open does).
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

      expect(find.text('DEVICE PAGE MARKER'), findsOneWidget,
          reason: 'device page should be on screen before the action');

      await tester.tap(find.byKey(const Key('now_action_block')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('now_duration_hour')));
      await tester.pumpAndSettle();

      // The override callback fired with the block kind.
      expect(kind, OverrideKind.block);
      // The sheet dismissed: its options are gone.
      expect(find.byKey(const Key('now_duration_hour')), findsNothing);
      // The device page is STILL the top route on the nested Navigator (the
      // bug popped it, leaving only HOME). canPop() is true only while the
      // pushed device route is still on the stack.
      expect(find.text('DEVICE PAGE MARKER'), findsOneWidget,
          reason: 'picking a duration must not pop the device page');
      expect(nestedKey.currentState!.canPop(), isTrue,
          reason: 'the device route must still be on the nested navigator '
              '(the bug popped it back to Home)');

      // Pop the device page ourselves so the ticker-bearing NowSection is
      // disposed before the test ends.
      nestedKey.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
