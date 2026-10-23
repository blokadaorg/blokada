import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/ui/activity_item.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [
        BlokadaTheme(
          bgColor: Colors.black,
          bgColorHome1: Colors.black,
          bgColorHome2: Colors.black,
          bgColorHome3: Colors.black,
          bgColorCard: Colors.black,
          panelBackground: Colors.black,
          cloud: Colors.blue,
          accent: Colors.orange,
          freemium: Colors.orange,
          shadow: Colors.black,
          bgMiniCard: Colors.black,
          textPrimary: Colors.white,
          textSecondary: Colors.white70,
          divider: Colors.grey,
        ),
      ]),
      home: Scaffold(body: child),
    );

UiJournalEntry _entry(UiJournalAction action) => UiJournalEntry(
      deviceName: "Example Phone",
      domainName: "ads.example.com",
      action: action,
      listId: "list1",
      profileId: null,
      timestamp: DateTime(2026, 1, 1),
    )..timestampText = "2 minutes ago";

void main() {
  // Screen readers used to hear only the domain and time, nothing saying
  // whether it was blocked or allowed.
  for (final (action, label) in [
    (UiJournalAction.block, "stats label blocked"),
    (UiJournalAction.allow, "stats label allowed"),
  ]) {
    testWidgets('a ${action.name} row says "${label.i18n}"', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(ActivityItem(entry: _entry(action))));

      final row = tester
          .getSemantics(find.bySemanticsIdentifier(AutomationIds.activityItem))
          .getSemanticsData()
          .label;
      expect(row, contains(label.i18n));
      expect(row, contains("ads.example.com"));
      handle.dispose();
    });
  }

  // Screen readers hear the domain first, then blocked or allowed, then time.
  testWidgets('the row reads domain, status, time in that order', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(ActivityItem(entry: _entry(UiJournalAction.block))));

    final row = tester
        .getSemantics(find.bySemanticsIdentifier(AutomationIds.activityItem))
        .getSemanticsData();
    expect(row.label, "ads.example.com\n${"stats label blocked".i18n}\n2 minutes ago");
    expect(row.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  // A small shield, but still with the cross or check inside, so blocked
  // and allowed differ by shape, not only by colour.
  for (final (action, icon) in [
    (UiJournalAction.block, CupertinoIcons.xmark_shield_fill),
    (UiJournalAction.allow, CupertinoIcons.checkmark_shield_fill),
  ]) {
    testWidgets('a ${action.name} row has a small shield with its mark', (tester) async {
      await tester.pumpWidget(_wrap(ActivityItem(entry: _entry(action))));

      final shield = tester.widget<Icon>(find.byIcon(icon));
      expect(shield.size, ActivityItem.iconSize);
      expect(ActivityItem.iconSize, lessThanOrEqualTo(24));
      expect(tester.getSize(find.byIcon(icon)).height, ActivityItem.iconSize);
    });
  }

  testWidgets('rows are the height the loading placeholder uses', (tester) async {
    await tester.pumpWidget(
      _wrap(Column(children: [ActivityItem(entry: _entry(UiJournalAction.block))])),
    );
    expect(tester.getSize(find.byType(ActivityItem)).height, ActivityItem.rowHeight);
  });

  testWidgets('a repeat count shares the time line, keeping the row height', (tester) async {
    final entry = UiJournalEntry(
      deviceName: "Example Phone",
      domainName: "ads.example.com",
      action: UiJournalAction.block,
      listId: "list1",
      profileId: null,
      timestamp: DateTime(2026, 1, 1),
      requests: 3,
    )..timestampText = "2 minutes ago";
    await tester.pumpWidget(_wrap(Column(children: [ActivityItem(entry: entry)])));

    expect(
      find.text("2 minutes ago · ${"family activity blocked times".i18n.withParams(3)}"),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(ActivityItem)).height, ActivityItem.rowHeight);
  });
}
