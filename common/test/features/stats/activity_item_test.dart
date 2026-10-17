import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/ui/activity_item.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/theme.dart';
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
}
