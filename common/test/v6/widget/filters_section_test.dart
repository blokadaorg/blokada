import 'package:common/src/app_variants/v6/widget/filters_section.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/filter/filter.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/blokada_switch.dart';
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

/// Records what the screen asks for instead of saving it.
class _RecordingFilterActor extends PlatformFilterActor {
  final mains = <BlocklistKey>[];
  final extras = <(BlocklistKey, bool)>[];

  @override
  Future<void> selectMainBlocklist(BlocklistKey key, Marker m) async => mains.add(key);

  @override
  Future<void> toggleExtraBlocklist(BlocklistKey key, bool on, Marker m) async =>
      extras.add((key, on));
}

/// A pick that lives in memory and counts changes, so the test sees whether
/// opening the screen changes it. Loading writes the same value back, which
/// is not a change.
class _MemoryPick extends BlocklistMainPick {
  var changes = 0;

  _MemoryPick(String? value) {
    load = (m) async => value;
    save = (m, v) async {
      if (v != value) changes++;
    };
  }
}

class _Screen {
  final _RecordingFilterActor actor;
  final _MemoryPick pick;

  _Screen(this.actor, this.pick);
}

Future<_Screen> _open(WidgetTester tester, List<FilterSelection> selected, {String? pick}) async {
  // Tall enough that the lazy list builds every row.
  tester.view.physicalSize = const Size(800, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  Core.register<KnownFilters>(KnownFilters(isFamily: false));
  final selection = SelectedFilters();
  await selection.change(Markers.testing, selected);
  Core.register<SelectedFilters>(selection);
  final mainPick = _MemoryPick(pick);
  Core.register<BlocklistMainPick>(mainPick);
  final actor = _RecordingFilterActor();
  Core.register<PlatformFilterActor>(actor);
  Core.register<AccountStore>(AccountStore());

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [_theme]),
      home: const Scaffold(body: V6FiltersSection()),
    ),
  );
  await tester.pump();
  return _Screen(actor, mainPick);
}

Finder _id(String id) =>
    find.byWidgetPredicate((it) => it is Semantics && it.properties.identifier == id);

String _mainId(String filter, String option) => "automation.blocklist_main.$filter.$option";

String _extraId(String filter, String option) => "automation.filter_option.$filter.$option";

bool _mainSelected(WidgetTester tester, String filter, String option) =>
    tester.widget<Semantics>(_id(_mainId(filter, option))).properties.selected ?? false;

BlokadaSwitch _switch(WidgetTester tester, String filter, String option) =>
    tester.widget<BlokadaSwitch>(
      find.descendant(of: _id(_extraId(filter, option)), matching: find.byType(BlokadaSwitch)),
    );

void main() {
  group("v6 blocklists screen", () {
    testWidgets("default account shows OISD Small as main and no extras", (tester) async {
      await withTrace((_) async {
        final s = await _open(tester, [
          FilterSelection("oisd", ["small"]),
        ]);

        expect(_mainSelected(tester, "oisd", "small"), isTrue);
        expect(_mainSelected(tester, "oisd", "big"), isFalse);
        // The main list is not offered again as an extra.
        expect(_id(_extraId("oisd", "small")), findsNothing);
        expect(_switch(tester, "oisd", "big").value, isFalse);
        expect(_switch(tester, "oisd", "nsfw").value, isFalse);
        expect(find.text("blocklists main pick".i18n), findsNothing);
        expect(_id(AutomationIds.blocklistsSummary), findsOneWidget);
        expect(_id(AutomationIds.blocklistsExceptions), findsOneWidget);
        expect(find.text("blocklists group adult".i18n), findsOneWidget);

        // Opening the screen saves nothing.
        expect(s.actor.mains, isEmpty);
        expect(s.actor.extras, isEmpty);
        expect(s.pick.changes, 0);
      });
    });

    testWidgets("main lists come in the agreed order", (tester) async {
      await withTrace((_) async {
        await _open(tester, [
          FilterSelection("oisd", ["small"]),
        ]);

        final tops = [
          for (final (f, o) in [
            ("oisd", "small"),
            ("oisd", "big"),
            ("stevenblack", "unified"),
            ("1hosts", "lite"),
            ("1hosts", "pro"),
            ("hblock", "standard"),
          ])
            tester.getTopLeft(_id(_mainId(f, o))).dy,
        ];
        expect(tops, [...tops]..sort());
      });
    });

    testWidgets("tapping another main list asks for the swap", (tester) async {
      await withTrace((_) async {
        final s = await _open(tester, [
          FilterSelection("oisd", ["small"]),
        ]);

        await tester.tap(_id(_mainId("stevenblack", "unified")));
        await tester.pump();
        // The current main list does nothing when tapped.
        await tester.tap(_id(_mainId("oisd", "small")));
        // Lets the press highlight finish.
        await tester.pump(const Duration(milliseconds: 300));

        expect(s.actor.mains, [const BlocklistKey("stevenblack", "unified")]);
        expect(s.actor.extras, isEmpty);
      });
    });

    testWidgets("an extra switch toggles that extra", (tester) async {
      await withTrace((_) async {
        final s = await _open(tester, [
          FilterSelection("oisd", ["small"]),
        ]);

        await tester.tap(
          find.descendant(
            of: _id(_extraId("stevenblack", "adult")),
            matching: find.byType(BlokadaSwitch),
          ),
        );
        await tester.pump();

        expect(s.actor.extras, [(const BlocklistKey("stevenblack", "adult"), true)]);
        expect(s.actor.mains, isEmpty);
      });
    });

    testWidgets("two general lists: the first in main order is main", (tester) async {
      await withTrace((_) async {
        await _open(tester, [
          FilterSelection("oisd", ["big"]),
          FilterSelection("stevenblack", ["unified"]),
        ]);

        expect(_mainSelected(tester, "oisd", "big"), isTrue);
        expect(_mainSelected(tester, "stevenblack", "unified"), isFalse);
        expect(_switch(tester, "stevenblack", "unified").value, isTrue);
        expect(_id(_extraId("oisd", "big")), findsNothing);
      });
    });

    testWidgets("a saved pick stays main", (tester) async {
      await withTrace((_) async {
        await _open(tester, [
          FilterSelection("oisd", ["big"]),
          FilterSelection("stevenblack", ["unified"]),
        ], pick: "stevenblack/unified");
        await tester.pump();

        expect(_mainSelected(tester, "stevenblack", "unified"), isTrue);
        expect(_switch(tester, "oisd", "big").value, isTrue);
      });
    });

    testWidgets("no main list: asks to pick one, picks none", (tester) async {
      await withTrace((_) async {
        final s = await _open(tester, [
          FilterSelection("adaway", ["standard"]),
        ]);

        expect(find.text("blocklists main pick".i18n), findsOneWidget);
        for (final key in v6MainBlocklists) {
          expect(_mainSelected(tester, key.filterName, key.optionName), isFalse);
          // General lists are offered only as the main one here.
          expect(_id(_extraId(key.filterName, key.optionName)), findsNothing);
        }
        // The only list on can't be turned off.
        expect(_switch(tester, "adaway", "standard").value, isTrue);
        expect(_switch(tester, "adaway", "standard").onChanged, isNull);
        expect(s.actor.mains, isEmpty);
        expect(s.pick.changes, 0);
      });
    });
  });
}
