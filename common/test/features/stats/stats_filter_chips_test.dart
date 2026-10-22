import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/ui/stats_filter_chips.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools.dart';

const _theme = BlokadaTheme(
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
);

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [_theme]),
      home: Scaffold(body: child),
    );

JournalFilter _default() => JournalFilter(
      showOnly: JournalFilterType.all,
      searchQuery: "",
      deviceName: "",
      sortNewestFirst: true,
      exactMatch: false,
    );

Finder _clear(String label) => find.bySemanticsLabel("${"universal action clear".i18n} $label");

void main() {
  group('statsFilterChips', () {
    test('no chips for the default filter', () {
      expect(statsFilterChips(_default()), isEmpty);
    });

    test('no chip for the device, which v6 narrows to by default', () {
      expect(statsFilterChips(_default().updateOnly(deviceName: "Example Phone")), isEmpty);
    });

    test('one chip per non-default field, each clearing only its field', () {
      final filter = _default().updateOnly(
        showOnly: JournalFilterType.blocked,
        searchQuery: "example.com",
        exactMatch: true,
        sortNewestFirst: false,
        deviceName: "Example Phone",
      );
      final chips = statsFilterChips(filter);
      expect(chips.map((it) => it.label), [
        "activity filter show blocked".i18n,
        "example.com",
        "activity filter exact match".i18n,
        "activity filter chip most common".i18n,
      ]);

      final cleared = chips.fold(filter, (f, chip) => chip.clear(f));
      expect(cleared.showOnly, JournalFilterType.all);
      expect(cleared.searchQuery, "");
      expect(cleared.exactMatch, isFalse);
      expect(cleared.sortNewestFirst, isTrue);
      expect(cleared.deviceName, "Example Phone");
      expect(statsFilterChips(cleared), isEmpty);
    });

    test('allowed only has its own chip', () {
      final chips = statsFilterChips(_default().updateOnly(showOnly: JournalFilterType.passed));
      expect(chips.single.label, "activity filter show allowed".i18n);
    });
  });

  group('StatsFilterChips', () {
    testWidgets('clearing chips one by one ends at the unfiltered list', (tester) async {
      await withTrace((m) async {
        final filter = JournalFilterValue();
        Core.register<JournalFilterValue>(filter);
        filter.now = _default().updateOnly(
          showOnly: JournalFilterType.blocked,
          searchQuery: "example.com",
        );

        await tester.pumpWidget(_wrap(const StatsFilterChips()));
        expect(find.text("activity filter show blocked".i18n), findsOneWidget);
        expect(find.text("example.com"), findsOneWidget);

        await tester.tap(_clear("example.com"));
        await _settle(tester);
        expect(filter.now.searchQuery, "");
        expect(filter.now.showOnly, JournalFilterType.blocked);
        expect(find.text("example.com"), findsNothing);
        expect(find.text("activity filter show blocked".i18n), findsOneWidget);

        await tester.tap(_clear("activity filter show blocked".i18n));
        await _settle(tester);
        expect(filter.now.showOnly, JournalFilterType.all);
        expect(statsFilterChips(filter.now), isEmpty);
        expect(find.byType(Wrap), findsNothing);

        await tester.pumpWidget(const SizedBox());
        // Let the press-highlight timers of the tapped chips fire.
        await tester.pump(const Duration(seconds: 1));
      });
    });

    testWidgets('shows a chip when the filter changes elsewhere', (tester) async {
      await withTrace((m) async {
        final filter = JournalFilterValue();
        Core.register<JournalFilterValue>(filter);

        await tester.pumpWidget(_wrap(const StatsFilterChips()));
        expect(find.byType(Wrap), findsNothing);

        filter.now = filter.now.updateOnly(exactMatch: true);
        await _settle(tester);
        expect(find.text("activity filter exact match".i18n), findsOneWidget);
      });
    });
  });

  group('StatsFilterAction', () {
    testWidgets('is tinted and selected only while filtered', (tester) async {
      await withTrace((m) async {
        final handle = tester.ensureSemantics();
        final filter = JournalFilterValue();
        Core.register<JournalFilterValue>(filter);

        await tester.pumpWidget(_wrap(const StatsFilterAction()));
        final search = find.text("universal action search".i18n);
        expect(tester.getSemantics(search), isNot(containsSemantics(isSelected: true)));
        expect(_bgColor(tester), isNull);

        filter.now = filter.now.updateOnly(searchQuery: "example.com");
        await _settle(tester);
        expect(tester.getSemantics(search), containsSemantics(isSelected: true));
        expect(_bgColor(tester), _theme.selection);

        filter.reset();
        await _settle(tester);
        expect(_bgColor(tester), isNull);
        handle.dispose();
      });
    });
  });
}

/// Value broadcasts its changes asynchronously, so the rebuild they trigger
/// can land a frame after the change.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// The tint the action settles on; the change itself eases in.
Color? _bgColor(WidgetTester tester) {
  final box = tester.widget<AnimatedContainer>(find
      .descendant(of: find.byType(StatsFilterAction), matching: find.byType(AnimatedContainer))
      .first);
  return (box.decoration as BoxDecoration).color;
}
