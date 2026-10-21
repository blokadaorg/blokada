import 'package:common/src/core/core.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/features/stats/ui/recent_activity.dart';
import 'package:common/src/features/stats/ui/top_domains.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/golden_tools.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await bootModules(tester);
  await tester.pumpWidget(
    BlokadaApp(
      isFamily: false,
      content: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

// Lets the tap's pending timers fire before the test ends.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

// Built after bootModules, which loads the translations.
Finder get retry => find.text("universal action try again".i18n);

void main() {
  testWidgets('toplists show an error with a retry, not "nothing to show"', (tester) async {
    var retried = 0;
    await _pump(
      tester,
      TopDomains(
        range: ToplistRange.daily,
        section: const StatsSection(StatsStatus.error),
        onRetry: () => retried++,
      ),
    );

    expect(find.text("privacy pulse empty".i18n), findsNothing);
    await tester.tap(retry);
    expect(retried, 1);
    await _unmount(tester);
  });

  testWidgets('recent activity shows an error with a retry, not "nothing to show"', (tester) async {
    var retried = 0;
    await _pump(
      tester,
      RecentActivity(section: const StatsSection(StatsStatus.error), onRetry: () => retried++),
    );

    expect(find.text("privacy pulse empty".i18n), findsNothing);
    await tester.tap(retry);
    expect(retried, 1);
    await _unmount(tester);
  });

  testWidgets('an empty section says there is nothing to show', (tester) async {
    await _pump(
      tester,
      RecentActivity(
        section: const StatsSection(StatsStatus.empty, RecentPreview(blocked: [], allowed: [])),
        onRetry: () {},
      ),
    );

    expect(find.text("privacy pulse empty".i18n), findsOneWidget);
    expect(retry, findsNothing);
  });
}
