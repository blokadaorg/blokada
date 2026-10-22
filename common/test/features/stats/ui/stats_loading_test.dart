import 'dart:async';

import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/features/stats/ui/activity_item.dart';
import 'package:common/src/features/stats/ui/recent_activity.dart';
import 'package:common/src/features/stats/ui/stats_section.dart' as activity;
import 'package:common/src/features/stats/ui/top_domains.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/fixtures.dart';
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

// Unmounts (stopping any shimmer) and lets pending timers fire.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

Finder get _placeholder => find.byType(LoadingPlaceholder);
Finder get _retry => find.text("universal action try again".i18n);

UiJournalEntry _entry(String domain, UiJournalAction action) => UiJournalEntry(
  deviceName: "Example Phone",
  domainName: domain,
  action: action,
  listId: "",
  profileId: null,
  timestamp: DateTime(2026, 1, 1),
)..timestampText = "2 minutes ago";

/// Holds every list load until [finish], then serves [result] or throws
/// [error].
class _GatedJournal extends JournalActor {
  var _gate = Completer<void>();
  List<UiJournalEntry> result = [];
  Object? error;
  bool more = false;
  Object? pageError;
  var pageRequests = 0;

  void finish() {
    _gate.complete();
    _gate = Completer<void>();
  }

  @override
  fetch(Marker m, {DeviceTag? tag, bool append = false}) async {
    if (append) {
      pageRequests++;
      if (pageError != null) throw pageError!;
      return;
    }
    await _gate.future;
    if (error != null) throw error!;
    hasMoreData = more;
    allEntries = result;
    filteredEntries.now = result;
  }
}

Future<_GatedJournal> _pumpActivity(WidgetTester tester) async {
  await bootModules(tester);
  await seedCloudAccount(tester);
  final journal = _GatedJournal();
  Core.di.allowReassignment = true;
  try {
    Core.register<JournalActor>(journal);
  } finally {
    Core.di.allowReassignment = false;
  }
  await tester.pumpWidget(
    BlokadaApp(
      isFamily: false,
      content: const Scaffold(body: activity.StatsSection(deviceTag: null, isHeader: false)),
    ),
  );
  await tester.pump();
  return journal;
}

Future<void> _finish(WidgetTester tester, _GatedJournal journal) async {
  journal.finish();
  await tester.pump();
  await tester.pump();
}

void main() {
  group('toplists', () {
    testWidgets('loading shows the placeholder, not a spinner', (tester) async {
      await _pump(
        tester,
        TopDomains(
          range: ToplistRange.daily,
          section: const StatsSection.loading(),
          onRetry: () {},
        ),
      );

      expect(_placeholder, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("privacy pulse empty".i18n), findsNothing);
      await _unmount(tester);
    });

    testWidgets('loaded data replaces the placeholder', (tester) async {
      await _pump(
        tester,
        TopDomains(
          range: ToplistRange.daily,
          section: StatsSection(
            StatsStatus.ready,
            PulseToplists(
              entries: [UiToplistEntry(null, "example.com", true, 12)],
              blockedDeltas: null,
              allowedDeltas: null,
            ),
          ),
          onRetry: () {},
        ),
      );

      expect(_placeholder, findsNothing);
      expect(find.text("example.com"), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('empty after loading says there is nothing to show', (tester) async {
      await _pump(
        tester,
        TopDomains(
          range: ToplistRange.daily,
          section: const StatsSection(
            StatsStatus.empty,
            PulseToplists(entries: [], blockedDeltas: null, allowedDeltas: null),
          ),
          onRetry: () {},
        ),
      );

      expect(_placeholder, findsNothing);
      expect(find.text("privacy pulse empty".i18n), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a failure shows the error, not the placeholder', (tester) async {
      await _pump(
        tester,
        TopDomains(
          range: ToplistRange.daily,
          section: const StatsSection(StatsStatus.error),
          onRetry: () {},
        ),
      );

      expect(_placeholder, findsNothing);
      expect(_retry, findsOneWidget);
      await _unmount(tester);
    });
  });

  group('recent activity', () {
    testWidgets('loading shows the placeholder, not a spinner', (tester) async {
      await _pump(tester, RecentActivity(section: const StatsSection.loading(), onRetry: () {}));

      expect(_placeholder, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("privacy pulse empty".i18n), findsNothing);
      await _unmount(tester);
    });

    testWidgets('loaded data replaces the placeholder', (tester) async {
      await _pump(
        tester,
        RecentActivity(
          section: StatsSection(
            StatsStatus.ready,
            RecentPreview(
              blocked: [_entry("ads.example.com", UiJournalAction.block)],
              allowed: const [],
            ),
          ),
          onRetry: () {},
        ),
      );

      expect(_placeholder, findsNothing);
      expect(find.text("ads.example.com"), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a failure shows the error, not the placeholder', (tester) async {
      await _pump(
        tester,
        RecentActivity(section: const StatsSection(StatsStatus.error), onRetry: () {}),
      );

      expect(_placeholder, findsNothing);
      expect(_retry, findsOneWidget);
      await _unmount(tester);
    });
  });

  group('activity list', () {
    testWidgets('shows the placeholder until the entries load', (tester) async {
      final journal = await _pumpActivity(tester);
      journal.result = [_entry("ads.example.com", UiJournalAction.block)];

      expect(_placeholder, findsOneWidget);
      expect(find.text("universal status waiting for data".i18n), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await _finish(tester, journal);
      expect(_placeholder, findsNothing);
      expect(find.byType(ActivityItem), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('says "waiting for data" only once loaded empty', (tester) async {
      final journal = await _pumpActivity(tester);

      expect(find.text("universal status waiting for data".i18n), findsNothing);
      await _finish(tester, journal);
      expect(_placeholder, findsNothing);
      expect(find.text("universal status waiting for data".i18n), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a failed page waits for the retry tap, not the next scroll', (tester) async {
      final journal = await _pumpActivity(tester);
      journal.more = true;
      journal.pageError = Exception("offline");
      journal.result = [
        for (var i = 0; i < 30; i++) _entry("ads$i.example.com", UiJournalAction.block),
      ];
      await _finish(tester, journal);

      final list = find.byType(Scrollable).first;
      await tester.drag(list, const Offset(0, -5000));
      await tester.pump();
      await tester.pump();
      expect(journal.pageRequests, 1);
      await tester.scrollUntilVisible(_retry, 300, scrollable: list);
      expect(_retry, findsOneWidget);

      // More scrolling at the bottom does not ask again.
      await tester.drag(list, const Offset(0, -500));
      await tester.pump();
      expect(journal.pageRequests, 1);

      journal.pageError = null;
      await tester.tap(_retry);
      await tester.pump();
      expect(journal.pageRequests, 2);
      await _unmount(tester);
    });

    testWidgets('a failed load shows the error with a retry that loads', (tester) async {
      final journal = await _pumpActivity(tester);
      journal.error = Exception("offline");

      await _finish(tester, journal);
      expect(_placeholder, findsNothing);
      expect(_retry, findsOneWidget);
      expect(find.text("universal status waiting for data".i18n), findsNothing);

      journal.error = null;
      journal.result = [_entry("ads.example.com", UiJournalAction.block)];
      await tester.tap(_retry);
      await tester.pump();
      expect(_placeholder, findsOneWidget);

      await _finish(tester, journal);
      expect(_retry, findsNothing);
      expect(find.byType(ActivityItem), findsOneWidget);
      await _unmount(tester);
    });
  });
}
