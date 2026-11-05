import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/features/stats/ui/top_domains.dart';
import 'package:common/src/platform/stats/delta_store.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/shared/layout/detail_pane_host.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/golden_tools.dart';

/// Records what a toplist row opens instead of rendering it.
class _CapturingPaneHost implements DetailPaneHandle {
  Object? arguments;

  @override
  bool get isActive => true;

  @override
  bool accepts(Paths path) => path == Paths.deviceStatsDetail;

  @override
  void show(Paths path, Object? arguments) => this.arguments = arguments;
}

void main() {
  testWidgets('a company-labelled row keys on its domain', (tester) async {
    await bootModules(tester);
    final host = _CapturingPaneHost();
    Core.get<DetailPaneHosts>().register(host);

    await tester.pumpWidget(
      BlokadaApp(
        isFamily: false,
        content: Scaffold(
          body: SingleChildScrollView(
            child: TopDomains(
              range: ToplistRange.weekly,
              section: StatsSection(
                StatsStatus.ready,
                PulseToplists(
                  entries: [
                    UiToplistEntry('Acme', 'acme.example', true, 12),
                    UiToplistEntry(null, 'plain.example', true, 6),
                  ],
                  blockedDeltas: [
                    ToplistDelta(
                      name: 'acme.example',
                      blocked: true,
                      newRank: 1,
                      previousRank: null,
                      type: ToplistDeltaType.newEntry,
                    ),
                  ],
                  allowedDeltas: null,
                ),
              ),
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('acme.example'), findsNothing);
    expect(find.text('plain.example'), findsOneWidget);
    // The delta keyed by domain still lands on the company-labelled row.
    expect(find.text('NEW'), findsOneWidget);

    await tester.tap(find.text('Acme'));
    await tester.pump();

    final args = host.arguments as Map;
    expect(args['domain'], 'acme.example');
    expect(args['level'], 2);
    expect((args['mainEntry'] as UiJournalMainEntry).domainName, 'acme.example');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
