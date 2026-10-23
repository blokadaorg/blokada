import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/features/stats/ui/horizontal_radial_segment.dart';
import 'package:common/src/features/stats/ui/top_domains.dart';
import 'package:common/src/features/stats/ui/totalcounter.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/minicard/chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/golden_tools.dart';

Future<void> _show(WidgetTester tester, Widget child, {bool reduceMotion = false}) async {
  final content = Scaffold(body: SingleChildScrollView(child: child));
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
}

// Unmounts and lets pending timers fire.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

UiStats _stats(int allowedPerHour) => UiStats(
  totalAllowed: 1000,
  totalBlocked: 400,
  allowedHistogram: List.filled(24, allowedPerHour),
  blockedHistogram: List.filled(24, 2),
  toplist: const [],
  avgDayTotal: 0,
  avgDayAllowed: 0,
  avgDayBlocked: 0,
  latestTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
);

const _counters = StatsCounters(allowed: 48, blocked: 20, total: 68);

Widget _segment(
  ToplistRange range, {
  int allowedPerHour = 2,
  StatsCounters? counters = _counters,
  bool statsReady = true,
}) => HorizontalRadialSegment(
  stats: _stats(allowedPerHour),
  range: range,
  counters: counters,
  statsReady: statsReady,
);

MiniCardChart _chart(WidgetTester tester) => tester.widget(find.byType(MiniCardChart));

/// Width factors of the toplist bars, top to bottom.
List<double> _bars(WidgetTester tester) => tester
    .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
    .map((it) => it.widthFactor!)
    .toList();

Widget _topDomains(ToplistRange range) => TopDomains(
  range: range,
  section: StatsSection(
    StatsStatus.ready,
    PulseToplists(
      entries: [
        UiToplistEntry(null, "first.example.com", true, 12),
        UiToplistEntry(null, "second.example.com", true, 6),
        UiToplistEntry(null, "third.example.com", true, 3),
      ],
      blockedDeltas: null,
      allowedDeltas: null,
    ),
  ),
  onRetry: () {},
);

String _totalText(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: find.byType(TotalCounter), matching: find.byType(Text)))
    .map((it) => it.data ?? "")
    .firstWhere((it) => RegExp(r'^[\d.]+[KM]?$').hasMatch(it));

void main() {
  group('trend line', () {
    testWidgets('draws in on first build, not when the stats refresh', (tester) async {
      await bootModules(tester);
      await _show(tester, _segment(ToplistRange.daily));
      expect(_chart(tester).animate, isTrue);
      final drawn = _chart(tester).key;

      await tester.pump(MiniCardChart.drawDuration);
      await _show(tester, _segment(ToplistRange.daily, allowedPerHour: 5));
      expect(_chart(tester).animate, isFalse);
      expect(_chart(tester).key, drawn);

      await _unmount(tester);
    });

    testWidgets('draws in again when the range changes', (tester) async {
      await bootModules(tester);
      await _show(tester, _segment(ToplistRange.daily));
      final daily = _chart(tester).key;
      await tester.pump(MiniCardChart.drawDuration);

      await _show(tester, _segment(ToplistRange.weekly));
      expect(_chart(tester).animate, isTrue);
      expect(_chart(tester).key, isNot(daily));

      await _unmount(tester);
    });

    testWidgets('waits for the chart\'s data, not only the counters', (tester) async {
      await bootModules(tester);
      await _show(tester, _segment(ToplistRange.daily, statsReady: false));
      expect(_chart(tester).animate, isFalse);

      // The data arrives after the draw would have ended: it still draws in.
      await tester.pump(MiniCardChart.drawDuration);
      await _show(tester, _segment(ToplistRange.daily));
      expect(_chart(tester).animate, isTrue);

      await _unmount(tester);
    });

    testWidgets('waits for the range\'s numbers before drawing in', (tester) async {
      await bootModules(tester);
      await _show(tester, _segment(ToplistRange.weekly, counters: null));
      expect(_chart(tester).animate, isFalse);

      await _show(tester, _segment(ToplistRange.weekly));
      expect(_chart(tester).animate, isTrue);

      await _unmount(tester);
    });

    testWidgets('with Reduce Motion it does not draw in', (tester) async {
      await bootModules(tester);
      await _show(tester, _segment(ToplistRange.daily), reduceMotion: true);
      expect(_chart(tester).animate, isFalse);

      await _show(tester, _segment(ToplistRange.weekly), reduceMotion: true);
      expect(_chart(tester).animate, isFalse);

      await _unmount(tester);
    });
  });

  group('toplist bars', () {
    testWidgets('are sized against the top entry and grow in', (tester) async {
      await bootModules(tester);
      await _show(tester, _topDomains(ToplistRange.daily));
      await tester.pump(const Duration(milliseconds: 100));
      final growing = _bars(tester);
      expect(growing[0], inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(_bars(tester), [1.0, 0.5, 0.25]);

      await _unmount(tester);
    });

    testWidgets('grow again when the range changes', (tester) async {
      await bootModules(tester);
      await _show(tester, _topDomains(ToplistRange.daily));
      await tester.pumpAndSettle();

      await _show(tester, _topDomains(ToplistRange.weekly));
      await tester.pump(const Duration(milliseconds: 100));
      // The incoming 7 d rows, under the fading 24 h ones.
      expect(_bars(tester).skip(3).first, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(_bars(tester), [1.0, 0.5, 0.25]);

      await _unmount(tester);
    });

    testWidgets('with Reduce Motion are drawn at their width', (tester) async {
      await bootModules(tester);
      await _show(tester, _topDomains(ToplistRange.daily), reduceMotion: true);
      expect(_bars(tester), [1.0, 0.5, 0.25]);

      await _unmount(tester);
    });
  });

  group('all-time total', () {
    final stats = UiStats.empty(totalBlocked: 12345);

    testWidgets('counts up in the short form', (tester) async {
      await bootModules(tester);
      await _show(tester, TotalCounter(stats: stats));
      expect(_totalText(tester), "0");

      await tester.pump(const Duration(milliseconds: 500));
      final halfway = _totalText(tester);
      expect(halfway, endsWith("K"));
      expect(halfway, isNot("12.3K"));

      await tester.pump(const Duration(seconds: 1));
      expect(_totalText(tester), "12.3K");

      await _unmount(tester);
    });

    testWidgets('with Reduce Motion shows the total at once', (tester) async {
      await bootModules(tester);
      await _show(tester, TotalCounter(stats: stats), reduceMotion: true);
      expect(_totalText(tester), "12.3K");

      await _unmount(tester);
    });
  });
}
