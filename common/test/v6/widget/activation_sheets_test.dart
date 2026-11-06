import 'package:common/src/app_variants/v6/module/activation/activation.dart';
import 'package:common/src/app_variants/v6/widget/activation/activation_intro_sheet.dart';
import 'package:common/src/app_variants/v6/widget/activation/first_blocks_sheet.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/ui/activity_item.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../golden/golden_tools.dart';

/// Records what the sheets ask of the actor, without a server.
class _FakeActivation extends V6ActivationActor {
  Set<ActivationGoal> initial = {};
  Set<ActivationGoal>? applied;
  bool asks = true;
  bool? answer;
  bool failAnswer = false;
  FirstBlocksMode mode = FirstBlocksMode.counterOnly;
  FirstBlocksSnapshot snapshot = const FirstBlocksSnapshot(7, []);
  int polls = 0;

  @override
  Set<ActivationGoal> currentGoals() => initial.toSet();

  @override
  Future<void> applyGoals(Set<ActivationGoal> picked, Marker m) async => applied = picked.toSet();

  @override
  bool get asksAboutLogging => asks;

  @override
  Future<void> answerLogging(bool enable, Marker m) async {
    if (failAnswer) throw Exception("offline");
    answer = enable;
  }

  @override
  FirstBlocksMode get firstBlocksMode => mode;

  @override
  Future<FirstBlocksSnapshot> pollFirstBlocks(Marker m) async {
    polls++;
    return snapshot;
  }
}

Future<_FakeActivation> _boot(WidgetTester tester) async {
  await bootModules(tester);
  final fake = _FakeActivation();
  Core.di.allowReassignment = true;
  try {
    Core.register<V6ActivationActor>(fake);
  } finally {
    Core.di.allowReassignment = false;
  }
  return fake;
}

/// Opens [sheet] as a route, the way the modal sheet does, so closing it
/// can be checked.
Future<void> _open(WidgetTester tester, Widget sheet) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => TopBarController(),
      child: BlokadaApp(
        isFamily: false,
        content: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => sheet)),
              child: const Text("open"),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text("open"));
  await tester.pumpAndSettle();
}

Finder _id(String id) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id);

Future<void> _tapId(WidgetTester tester, String id) async {
  await tester.tap(_id(id));
  await tester.pumpAndSettle();
}

void main() {
  group("activation intro", () {
    testWidgets("picks goals, then answers the logging question", (tester) async {
      final fake = await _boot(tester);
      fake.initial = {ActivationGoal.adult};
      await _open(tester, const ActivationIntroSheet());

      expect(find.text("activation goals header".i18n), findsOneWidget);
      await _tapId(tester, AutomationIds.activationGoalAppAds);
      await _tapId(tester, AutomationIds.activationGoalAdult);
      await _tapId(tester, AutomationIds.activationGoalsContinue);

      expect(fake.applied, {ActivationGoal.appAds});
      expect(find.text("activity logging offer header".i18n), findsOneWidget);
      expect(find.text("activity logging offer brief".i18n), findsOneWidget);

      await _tapId(tester, AutomationIds.activationLoggingSkip);

      expect(fake.answer, isFalse);
      expect(find.byType(ActivationIntroSheet), findsNothing);
    });

    testWidgets("goals are checkable for screen readers", (tester) async {
      final semantics = tester.ensureSemantics();
      final fake = await _boot(tester);
      fake.initial = {ActivationGoal.scams};
      await _open(tester, const ActivationIntroSheet());

      expect(
        tester.getSemantics(find.text("activation goal scams".i18n)),
        containsSemantics(
          identifier: AutomationIds.activationGoalScams,
          isChecked: true,
          isButton: true,
        ),
      );
      expect(
        tester.getSemantics(find.text("activation goal trackers".i18n)),
        containsSemantics(identifier: AutomationIds.activationGoalTrackers, isChecked: false),
      );
      semantics.dispose();
    });

    testWidgets("skips the logging question when logging is already on", (tester) async {
      final fake = await _boot(tester);
      fake.asks = false;
      await _open(tester, const ActivationIntroSheet());

      await _tapId(tester, AutomationIds.activationGoalsContinue);

      expect(fake.applied, isEmpty);
      expect(find.byType(ActivationIntroSheet), findsNothing);
    });

    testWidgets("a failed opt-in stays on the question", (tester) async {
      final fake = await _boot(tester);
      fake.failAnswer = true;
      await _open(tester, const ActivationIntroSheet());

      await _tapId(tester, AutomationIds.activationGoalsContinue);
      await _tapId(tester, AutomationIds.activationLoggingEnable);

      expect(find.byType(ActivationIntroSheet), findsOneWidget);
      expect(find.text("activity logging offer header".i18n), findsOneWidget);
    });
  });

  group("first blocks", () {
    testWidgets("counter only while logging is off", (tester) async {
      final fake = await _boot(tester);
      fake.mode = FirstBlocksMode.counterOnly;
      await _open(tester, const FirstBlocksSheet());

      expect(find.text("7"), findsOneWidget);
      expect(find.text("activation first blocks brief counter".i18n), findsOneWidget);
      expect(find.text("activation first blocks waiting".i18n), findsNothing);
      expect(find.byType(ActivityItem), findsNothing);

      await _tapId(tester, AutomationIds.activationFirstBlocksDone);
      expect(find.byType(FirstBlocksSheet), findsNothing);
    });

    testWidgets("feed and counter with logging on", (tester) async {
      final fake = await _boot(tester);
      fake.mode = FirstBlocksMode.feedAndCounter;
      final entry = UiJournalEntry(
        deviceName: "Pixel",
        domainName: "ads.example.com",
        action: UiJournalAction.block,
        listId: "list",
        profileId: null,
        timestamp: DateTime(2026, 11, 6, 12),
      )..timestampText = "now";
      fake.snapshot = FirstBlocksSnapshot(3, [entry]);
      await _open(tester, const FirstBlocksSheet());

      expect(find.text("3"), findsOneWidget);
      expect(find.text("activation first blocks brief".i18n), findsOneWidget);
      expect(find.byType(ActivityItem), findsOneWidget);

      await _tapId(tester, AutomationIds.activationFirstBlocksDone);
    });

    testWidgets("refreshes for about a minute, then stops", (tester) async {
      final fake = await _boot(tester);
      await _open(tester, const FirstBlocksSheet());
      final first = fake.polls;

      await tester.pump(FirstBlocksSheet.refreshEvery);
      expect(fake.polls, first + 1);

      await tester.pump(FirstBlocksSheet.liveFor);
      final stopped = fake.polls;
      await tester.pump(FirstBlocksSheet.liveFor);
      expect(fake.polls, stopped);
      expect(
        stopped - first,
        FirstBlocksSheet.liveFor.inSeconds ~/ FirstBlocksSheet.refreshEvery.inSeconds,
      );

      await _tapId(tester, AutomationIds.activationFirstBlocksDone);
    });
  });
}
