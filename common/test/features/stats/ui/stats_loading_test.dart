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
import 'package:common/src/shared/ui/crossfade.dart';
import 'package:common/src/shared/ui/placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

UiJournalEntry _entry(String domain, UiJournalAction action, {DateTime? at}) => UiJournalEntry(
  deviceName: "Example Phone",
  domainName: domain,
  action: action,
  listId: "",
  profileId: null,
  timestamp: at ?? DateTime(2026, 1, 1),
)..timestampText = "2 minutes ago";

// Reduce Motion on, at the test view's real size.
Widget _reduced(WidgetTester tester, Widget child) => MediaQuery(
  data: MediaQueryData.fromView(tester.view).copyWith(disableAnimations: true),
  child: child,
);

/// Records the haptics sent to the platform.
List<String> _recordHaptics(WidgetTester tester) {
  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) {
    if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return haptics;
}

/// The opacity [text] is drawn with, through any fades above it.
double _opacityOf(WidgetTester tester, Finder text) {
  var opacity = 1.0;
  for (final fade in tester.widgetList<FadeTransition>(
    find.ancestor(of: text, matching: find.byType(FadeTransition)),
  )) {
    opacity *= fade.opacity.value;
  }
  return opacity;
}

final _toplists = PulseToplists(
  entries: [
    UiToplistEntry(null, "blocked.example.com", true, 12),
    UiToplistEntry(null, "allowed.example.com", false, 7),
  ],
  blockedDeltas: null,
  allowedDeltas: null,
);

/// Holds every list load until [finish], then serves [result] or throws
/// [error].
class _GatedJournal extends JournalActor {
  var _gate = Completer<void>();
  List<UiJournalEntry> result = [];
  Object? error;
  bool more = false;
  Object? pageError;
  var pageRequests = 0;
  var loads = 0;

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
    loads++;
    await _gate.future;
    if (error != null) throw error!;
    hasMoreData = more;
    allEntries = result;
    filteredEntries.now = result;
  }
}

Future<_GatedJournal> _pumpActivity(WidgetTester tester, {bool reduceMotion = false}) async {
  await bootModules(tester);
  await seedCloudAccount(tester);
  final journal = _GatedJournal();
  Core.di.allowReassignment = true;
  try {
    Core.register<JournalActor>(journal);
  } finally {
    Core.di.allowReassignment = false;
  }
  const content = Scaffold(body: activity.StatsSection(deviceTag: null, isHeader: false));
  await tester.pumpWidget(
    BlokadaApp(isFamily: false, content: reduceMotion ? _reduced(tester, content) : content),
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

  group('smooth changes', () {
    Widget topDomains(ToplistRange range) => TopDomains(
      range: range,
      section: StatsSection(StatsStatus.ready, _toplists),
      onRetry: () {},
    );

    testWidgets('switching Blocked and Allowed crossfades the toplist', (tester) async {
      await _pump(tester, topDomains(ToplistRange.daily));
      expect(find.text("allowed.example.com"), findsNothing);

      await tester.tap(find.text("privacy pulse tab allowed".i18n));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      // Halfway: both lists drawn, the old one fading out.
      expect(find.text("blocked.example.com"), findsOneWidget);
      expect(find.text("allowed.example.com"), findsOneWidget);
      expect(_opacityOf(tester, find.text("blocked.example.com")), inExclusiveRange(0, 1));
      expect(_opacityOf(tester, find.text("allowed.example.com")), inExclusiveRange(0, 1));

      await tester.pump(Crossfade.duration);
      expect(find.text("blocked.example.com"), findsNothing);
      expect(_opacityOf(tester, find.text("allowed.example.com")), 1.0);
      await _unmount(tester);
    });

    testWidgets('switching 24h and 7d crossfades the toplist', (tester) async {
      await _pump(tester, topDomains(ToplistRange.daily));
      await tester.pumpWidget(
        BlokadaApp(
          isFamily: false,
          content: Scaffold(body: SingleChildScrollView(child: topDomains(ToplistRange.weekly))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 75));
      // The outgoing 24h list and the incoming 7d one.
      expect(find.text("blocked.example.com"), findsNWidgets(2));
      expect(find.byType(AnimatedSize), findsOneWidget);

      await tester.pump(Crossfade.duration);
      expect(find.text("blocked.example.com"), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('switching Blocked and Allowed in recent activity crossfades', (tester) async {
      await _pump(
        tester,
        RecentActivity(
          section: StatsSection(
            StatsStatus.ready,
            RecentPreview(
              blocked: [_entry("ads.example.com", UiJournalAction.block)],
              allowed: [_entry("cdn.example.com", UiJournalAction.allow)],
            ),
          ),
          onRetry: () {},
        ),
      );

      await tester.tap(find.text("privacy pulse tab allowed".i18n));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(_opacityOf(tester, find.text("ads.example.com")), inExclusiveRange(0, 1));
      expect(_opacityOf(tester, find.text("cdn.example.com")), inExclusiveRange(0, 1));

      await tester.pump(Crossfade.duration);
      expect(find.text("ads.example.com"), findsNothing);
      await _unmount(tester);
    });

    testWidgets('with Reduce Motion the switch is a plain fade', (tester) async {
      await _pump(
        tester,
        Builder(builder: (_) => _reduced(tester, topDomains(ToplistRange.daily))),
      );
      expect(find.byType(AnimatedSize), findsNothing);

      await tester.tap(find.text("privacy pulse tab allowed".i18n));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(_opacityOf(tester, find.text("allowed.example.com")), inExclusiveRange(0, 1));

      await tester.pump(Crossfade.duration);
      expect(find.text("blocked.example.com"), findsNothing);
      expect(find.byType(AnimatedSize), findsNothing);
      await _unmount(tester);
    });

    // A short list doesn't scroll, so this starts the indicator the way a pull does.
    Future<void> pullToRefresh(WidgetTester tester) async {
      unawaited(tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('pull to refresh keeps the rows and fades in new ones', (tester) async {
      final haptics = _recordHaptics(tester);
      final journal = await _pumpActivity(tester);
      final old = _entry("ads.example.com", UiJournalAction.block);
      journal.result = [old];
      await _finish(tester, journal);
      expect(find.byType(ActivityItem), findsOneWidget);

      journal.result = [
        _entry("new.example.com", UiJournalAction.block, at: DateTime(2026, 1, 2)),
        old,
      ];
      await pullToRefresh(tester);

      // Still loading: the old row stays, no placeholder, no empty text.
      expect(find.text("ads.example.com"), findsOneWidget);
      expect(_placeholder, findsNothing);
      expect(find.text("universal status waiting for data".i18n), findsNothing);
      expect(haptics, ['HapticFeedbackType.lightImpact']);

      await _finish(tester, journal);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ActivityItem), findsNWidgets(2));
      expect(_opacityOf(tester, find.text("new.example.com")), inExclusiveRange(0, 1));
      expect(_opacityOf(tester, find.text("ads.example.com")), 1.0);

      await tester.pump(const Duration(milliseconds: 300));
      expect(_opacityOf(tester, find.text("new.example.com")), 1.0);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      await _unmount(tester);
    });

    testWidgets('no page loads while a refresh is in flight', (tester) async {
      final journal = await _pumpActivity(tester);
      journal.more = true;
      journal.result = [
        for (var i = 0; i < 30; i++) _entry("ads$i.example.com", UiJournalAction.block),
      ];
      await _finish(tester, journal);
      expect(journal.pageRequests, 0);

      await pullToRefresh(tester);
      final list = find.byType(Scrollable).first;
      await tester.drag(list, const Offset(0, -5000));
      await tester.pump();
      expect(journal.pageRequests, 0);

      await _finish(tester, journal);
      await tester.drag(list, const Offset(0, -500));
      await tester.pump();
      expect(journal.pageRequests, 1);
      await _unmount(tester);
    });

    testWidgets('a failed refresh shows the error', (tester) async {
      final journal = await _pumpActivity(tester);
      journal.result = [_entry("ads.example.com", UiJournalAction.block)];
      await _finish(tester, journal);

      journal.error = Exception("offline");
      await pullToRefresh(tester);
      await _finish(tester, journal);
      expect(_retry, findsOneWidget);
      expect(_placeholder, findsNothing);
      await _unmount(tester);
    });

    testWidgets('with Reduce Motion a refresh still keeps the rows', (tester) async {
      final journal = await _pumpActivity(tester, reduceMotion: true);
      journal.result = [_entry("ads.example.com", UiJournalAction.block)];
      await _finish(tester, journal);

      await pullToRefresh(tester);
      expect(find.text("ads.example.com"), findsOneWidget);
      expect(_placeholder, findsNothing);

      await _finish(tester, journal);
      expect(find.text("ads.example.com"), findsOneWidget);
      expect(_opacityOf(tester, find.text("ads.example.com")), 1.0);
      await _unmount(tester);
    });
  });
}
