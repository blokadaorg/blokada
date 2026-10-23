import 'package:common/src/core/core.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/features/stats/ui/privacy_pulse_charts.dart';
import 'package:common/src/platform/stats/delta_store.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/golden_tools.dart';

StatsCounters _blocked(int blocked) =>
    StatsCounters(allowed: 100, blocked: blocked, total: 100 + blocked);

CounterDelta _delta(int blockedPercent, {bool hasComparison = true}) =>
    CounterDelta(allowedPercent: 0, blockedPercent: blockedPercent, hasComparison: hasComparison);

String _insight(int blocked, {ToplistRange range = ToplistRange.daily, CounterDelta? delta}) =>
    PrivacyPulseCharts.insight(counters: _blocked(blocked), range: range, delta: delta);

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

void main() {
  group('insight line', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await I18nService.loadTranslations();
    });

    test('without a comparison shows the count only', () {
      expect(_insight(36), "36 blocked in 24 h");
      expect(_insight(36, delta: _delta(-12, hasComparison: false)), "36 blocked in 24 h");
      expect(_insight(36, delta: _delta(0)), "36 blocked in 24 h");
    });

    test('adds the comparison with the period before', () {
      expect(
        _insight(36, delta: _delta(-12)),
        "36 blocked in 24 h · 12% fewer than the 24 h before",
      );
      expect(_insight(36, delta: _delta(40)), "36 blocked in 24 h · 40% more than the 24 h before");
      expect(
        _insight(250, range: ToplistRange.weekly, delta: _delta(-5)),
        "250 blocked in 7 d · 5% fewer than the week before",
      );
      expect(
        _insight(250, range: ToplistRange.weekly, delta: _delta(8)),
        "250 blocked in 7 d · 8% more than the week before",
      );
    });

    test('uses the singular form for one, the plural otherwise', () {
      final range = "stats range 24h".i18n;
      expect(_insight(1), "privacy pulse insight blocked one".i18n.withParams("1", range));
      expect(_insight(0), "privacy pulse insight blocked many".i18n.withParams("0", range));
      expect(_insight(2), "privacy pulse insight blocked many".i18n.withParams("2", range));
    });

    test('keeps big counts short', () {
      expect(_insight(12345), "12.3K blocked in 24 h");
    });
  });

  group('Pulse card', () {
    Future<void> show(WidgetTester tester, {StatsCounters? counters, CounterDelta? delta}) async {
      await bootModules(tester);
      await tester.pumpWidget(
        BlokadaApp(
          isFamily: false,
          content: Scaffold(
            body: PrivacyPulseCharts(
              stats: UiStats.empty(),
              counters: counters,
              counterDelta: delta,
              trailing: const Text("range switch"),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('leads with the insight, not the title and a generic sentence', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, counters: _blocked(36), delta: _delta(-12));

      const line = "36 blocked in 24 h · 12% fewer than the 24 h before";
      expect(find.text(line), findsOneWidget);
      expect(find.bySemanticsLabel(line), findsOneWidget);
      expect(find.text("privacy pulse section header".i18n), findsNothing);
      expect(find.text("privacy pulse brief".i18n), findsNothing);
      // The 24 h / 7 d switch stays in the card.
      expect(find.text("range switch"), findsOneWidget);

      semantics.dispose();
      await _unmount(tester);
    });

    testWidgets('shows a placeholder until the numbers load', (tester) async {
      await show(tester);
      expect(find.byType(LoadingPlaceholder), findsWidgets);
      expect(find.textContaining("blocked in"), findsNothing);

      await _unmount(tester);
    });
  });
}
