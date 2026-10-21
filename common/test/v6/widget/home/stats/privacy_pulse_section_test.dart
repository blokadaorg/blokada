import 'package:common/src/app_variants/v6/widget/home/stats/privacy_pulse_section.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  await tester.pumpWidget(
    BlokadaApp(
      isFamily: false,
      content: Scaffold(body: PrivacyPulseSection(controller: ScrollController())),
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
}
