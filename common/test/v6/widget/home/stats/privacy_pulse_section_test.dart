import 'package:common/src/app_variants/v6/widget/home/stats/privacy_pulse_section.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/weekly/ui/weekly_report_card.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../../../../golden/fixtures.dart';
import '../../../../golden/golden_tools.dart';

/// Holds whatever sections the test sets and records retries, without
/// fetching anything.
class _FixedStatsController extends StatsController {
  final retried = <StatsPart>[];

  @override
  Future<void> openPulse(Marker m, {ToplistRange? initialRange}) async {}

  @override
  void closePulse() {}

  @override
  Future<void> retry(Marker m, StatsPart part) async => retried.add(part);
}

Future<_FixedStatsController> _pump(
  WidgetTester tester, {
  required StatsSection<PulseCounters> counters,
  WeeklyReportEvent? weekly,
  bool reduceMotion = false,
}) async {
  await bootModules(tester);
  await seedCloudAccount(tester);
  final controller = _FixedStatsController();
  Core.di.allowReassignment = true;
  try {
    Core.register<StatsController>(controller);
  } finally {
    Core.di.allowReassignment = false;
  }
  controller.range.now = ToplistRange.weekly;
  controller.stats.now = const StatsSection(StatsStatus.error);
  controller.counters.now = counters;
  if (weekly != null) {
    mobx.runInAction(() => Core.get<WeeklyReportActor>().currentEvent.value = weekly);
  }

  final content = Scaffold(body: PrivacyPulseSection(controller: ScrollController()));
  await tester.pumpWidget(
    BlokadaApp(
      isFamily: false,
      content: reduceMotion
          ? MediaQuery(
              data: MediaQueryData.fromView(tester.view).copyWith(disableAnimations: true),
              child: content,
            )
          : content,
    ),
  );
  await tester.pump();
  return controller;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

const _weekCounters = StatsSection(
  StatsStatus.ready,
  PulseCounters(
    counters: StatsCounters(allowed: 200, blocked: 90, total: 290),
    delta: null,
    deltaReady: true,
    sparkline: null,
  ),
);

final _weeklyEvent = WeeklyReportEvent(
  id: "example-week",
  title: "Example weekly title",
  body: "Example weekly body",
  type: WeeklyReportEventType.totalsDelta,
  icon: WeeklyReportIcon.chart,
  score: 1,
  generatedAt: DateTime(2026, 1, 1),
);

Finder get _weeklyCard => find.byType(WeeklyReportCard);

Future<void> _closeWeeklyCard(WidgetTester tester) async {
  await tester.tap(find.descendant(of: _weeklyCard, matching: find.byIcon(CupertinoIcons.clear)));
  await tester.pump();
}

/// The weekly card's size and fade factors, while it closes.
(double size, double opacity) _exitOf(WidgetTester tester) {
  final sizes = tester.widgetList<SizeTransition>(
    find.ancestor(of: _weeklyCard, matching: find.byType(SizeTransition)),
  );
  final fades = tester.widgetList<FadeTransition>(
    find.ancestor(of: _weeklyCard, matching: find.byType(FadeTransition)),
  );
  return (
    sizes.fold(1.0, (a, it) => a * it.sizeFactor.value),
    fades.fold(1.0, (a, it) => a * it.opacity.value),
  );
}

void main() {
  testWidgets('failed stats with nothing to show offer a retry, not zeros', (tester) async {
    final controller = await _pump(tester, counters: _weekCounters);

    final retry = find.text("universal action try again".i18n);
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    expect(controller.retried, [StatsPart.stats]);

    await _unmount(tester);
  });

  testWidgets('a counters failure takes precedence', (tester) async {
    final controller = await _pump(tester, counters: const StatsSection(StatsStatus.error));

    final retry = find.text("universal action try again".i18n);
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    expect(controller.retried, [StatsPart.counters]);

    await _unmount(tester);
  });

  testWidgets('a closed weekly card shrinks and fades, then is gone', (tester) async {
    await _pump(tester, counters: _weekCounters, weekly: _weeklyEvent);
    expect(_weeklyCard, findsOneWidget);
    final top = tester.getTopLeft(find.text("Example weekly title")).dy;
    // Below the card in both layouts.
    final below = find.text("privacy pulse recents header".i18n);
    final belowBefore = tester.getTopLeft(below).dy;

    await _closeWeeklyCard(tester);
    await tester.pump(const Duration(milliseconds: 125));
    final (size, opacity) = _exitOf(tester);
    expect(size, inExclusiveRange(0, 1));
    expect(opacity, inExclusiveRange(0, 1));
    // The content below moves up with it, not in one jump.
    final belowMid = tester.getTopLeft(below).dy;
    expect(belowMid, lessThan(belowBefore));
    expect(tester.getTopLeft(find.text("Example weekly title")).dy, top);

    await tester.pump(const Duration(milliseconds: 200));
    expect(_weeklyCard, findsNothing);
    expect(tester.getTopLeft(below).dy, lessThan(belowMid));

    await _unmount(tester);
  });

  testWidgets('with Reduce Motion a closed weekly card only fades', (tester) async {
    await _pump(tester, counters: _weekCounters, weekly: _weeklyEvent, reduceMotion: true);
    // Below the card in both layouts.
    final below = find.text("privacy pulse recents header".i18n);
    final belowBefore = tester.getTopLeft(below).dy;

    await _closeWeeklyCard(tester);
    await tester.pump(const Duration(milliseconds: 125));
    expect(find.ancestor(of: _weeklyCard, matching: find.byType(SizeTransition)), findsNothing);
    expect(_exitOf(tester).$2, inExclusiveRange(0, 1));
    expect(tester.getTopLeft(below).dy, belowBefore);

    await tester.pump(const Duration(milliseconds: 200));
    expect(_weeklyCard, findsNothing);
    expect(tester.getTopLeft(below).dy, lessThan(belowBefore));

    await _unmount(tester);
  });
}
