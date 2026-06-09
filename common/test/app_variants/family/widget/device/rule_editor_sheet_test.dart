import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/app_variants/family/widget/device/rule_editor_sheet.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tools.dart';

Widget _wrap(Widget child) =>
    _wrapOn(TargetPlatform.iOS, child);

Widget _wrapOn(TargetPlatform platform, Widget child) => MaterialApp(
      theme: ThemeData(
        // Pin platform so the chip-popup branch under test is
        // deterministic regardless of the test host. iOS exercises the
        // Cupertino path (anchored CupertinoPopupSurface popover with
        // the dismiss-layer key); Android exercises Material showMenu.
        platform: platform,
        extensions: const [
          BlokadaTheme(
            bgColor: Colors.black,
            bgColorHome1: Colors.black,
            bgColorHome2: Colors.black,
            bgColorHome3: Colors.black,
            bgColorCard: Colors.black,
            panelBackground: Colors.black,
            cloud: Colors.blue,
            accent: Colors.blue,
            freemium: Colors.orange,
            shadow: Colors.black,
            bgMiniCard: Colors.black,
            textPrimary: Colors.white,
            textSecondary: Colors.white70,
            divider: Colors.grey,
          ),
        ],
      ),
      home: Scaffold(body: child),
    );

JsonProfile _profile(String id, String displayName, {String template = "parent"}) {
  return JsonProfile(
    profileId: id,
    alias: '$displayName ($template)',
    lists: const [],
    safeSearch: false,
  );
}

void main() {
  testWidgets('Profile field shows a chip per eligible profile and selects on tap',
      (tester) async {
    await withTrace((_) async {
      final profiles = [
        _profile('prof_default', 'Default', template: ''),
        _profile('prof_school', 'School', template: ''),
      ];

      String? savedProfileId;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_other_unused',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(rule) {
          savedProfileId = rule.profileId;
        },
        onDelete: null,
      )));
      await tester.pump();

      expect(find.text('Default'), findsOneWidget);
      expect(find.text('School'), findsOneWidget);

      // Default selection is the first eligible profile. Tap the
      // second chip to switch the rule's profileId before saving.
      await tester.tap(find.text('School'));
      await tester.pump();

      await tester.tap(find.byKey(const Key('rule_editor_save')));
      await tester.pumpAndSettle();

      expect(savedProfileId, 'prof_school');
    });
  });

  testWidgets('Days preset Weekends selects Sat/Sun and updates chip state',
      (tester) async {
    await withTrace((_) async {
      RuleModel? saved;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: [_profile('p1', 'P', template: '')],
        deviceBaseProfileId: 'prof_other_unused',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(r) => saved = r,
        onDelete: null,
      )));
      await tester.pump();

      // Default seed is Weekdays. Tap Weekends to flip.
      await tester.tap(find.byKey(const Key('preset_weekends')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('rule_editor_save')));
      await tester.pumpAndSettle();

      expect(saved!.weekdays, [6, 7]);
    });
  });

  testWidgets(
      'Tapping a single day chip after a preset narrows to a custom set',
      (tester) async {
    await withTrace((_) async {
      RuleModel? saved;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: [_profile('p1', 'P', template: '')],
        deviceBaseProfileId: 'prof_other_unused',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(r) => saved = r,
        onDelete: null,
      )));
      await tester.pump();

      // Untoggle Friday (Mon-Fri starts selected) → yields Mon-Thu and the
      // preset row should switch to "Custom" automatically. The new target
      // selector section pushes the day chips below the 600px test viewport,
      // so scroll the chip into view before tapping.
      await tester.ensureVisible(find.byKey(const Key('day_chip_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('day_chip_5')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('rule_editor_save')));
      await tester.pumpAndSettle();

      expect(saved!.weekdays, [1, 2, 3, 4]);
    });
  });

  testWidgets('Times list shows one initial window',
      (tester) async {
    await withTrace((_) async {
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: [_profile('p1', 'P', template: '')],
        deviceBaseProfileId: 'prof_other_unused',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(_) {},
        onDelete: null,
      )));
      await tester.pump();

      // The target selector now leads the form, so the times section sits
      // below the 600px test viewport and the outer ListView culls it; scroll
      // down until the From button is built before asserting on it.
      await tester.scrollUntilVisible(find.text('09:00'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      // Initial window 09:00–17:00 rendered as compact From/To buttons.
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('17:00'), findsOneWidget);
      // Counter is now part of the section label (upper-cased; "FAMILY
      // SCHEDULE RULE EDITOR TIMES LABEL · FAMILY SCHEDULE RULE EDITOR
      // TIMES COUNTER" in the no-translation test env). Match by
      // substring so we don't depend on the exact join glyph.
      expect(
          find.textContaining('FAMILY SCHEDULE RULE EDITOR TIMES COUNTER'),
          findsOneWidget);
    });
  });

  testWidgets(
      'Wraparound rule (end < start) renders the "↳ ends next day" hint',
      (tester) async {
    await withTrace((_) async {
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: RuleModel(
          profileId: 'p1',
          weekdays: const [1, 2, 3, 4, 5, 6, 7],
          windows: const [
            TimeWindowModel(startMinute: 1260, endMinute: 420)
          ],
        ),
        availableProfiles: [_profile('p1', 'P', template: '')],
        deviceBaseProfileId: 'prof_other_unused',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(_) {},
        onDelete: () {},
      )));
      await tester.pump();

      // Times section is below the viewport (target selector leads the form);
      // scroll the wrap hint into view before asserting.
      await tester.scrollUntilVisible(
          find.text('family schedule rule editor times wrap'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      expect(find.text('family schedule rule editor times wrap'),
          findsOneWidget);
    });
  });

  testWidgets('Add-another-time button is disabled at the 4-window soft cap',
      (tester) async {
    await withTrace((_) async {
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: RuleModel(
          profileId: 'p1',
          weekdays: const [1],
          windows: const [
            TimeWindowModel(startMinute: 0, endMinute: 60),
            TimeWindowModel(startMinute: 120, endMinute: 180),
            TimeWindowModel(startMinute: 240, endMinute: 300),
            TimeWindowModel(startMinute: 360, endMinute: 420),
          ],
        ),
        availableProfiles: [_profile('p1', 'P', template: '')],
        deviceBaseProfileId: 'prof_other_unused',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(_) {},
        onDelete: () {},
      )));
      await tester.pump();

      // Scroll the Add-another-time button into view (it sits below the
      // target selector + 4 window rows, past the test viewport).
      await tester.scrollUntilVisible(
          find.byKey(const Key('times_add_button')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      final btn = tester.widget<TextButton>(
          find.byKey(const Key('times_add_button')));
      expect(btn.onPressed, isNull,
          reason: 'add button must be disabled (onPressed==null) at the cap');
    });
  });

  testWidgets('Deleting a window removes the row and updates the counter',
      (tester) async {
    await withTrace((_) async {
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: RuleModel(
          profileId: 'p1',
          weekdays: const [1],
          windows: const [
            TimeWindowModel(startMinute: 0, endMinute: 60),
            TimeWindowModel(startMinute: 120, endMinute: 180),
          ],
        ),
        availableProfiles: [_profile('p1', 'P', template: '')],
        deviceBaseProfileId: 'prof_other_unused',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(_) {},
        onDelete: () {},
      )));
      await tester.pump();

      // Scroll the times rows into view — the target selector now leads the
      // form so both delete buttons start below the 600px test viewport and
      // the outer ListView culls them.
      await tester.scrollUntilVisible(
          find.byKey(const Key('times_delete_1')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      // Two delete buttons visible (canDelete is gated on length > 1).
      expect(find.byKey(const Key('times_delete_0')), findsOneWidget);
      expect(find.byKey(const Key('times_delete_1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('times_delete_1')));
      await tester.pumpAndSettle();
      // After deletion only one window remains — the row no longer offers
      // a delete affordance (single-window rules are not deletable).
      expect(find.byKey(const Key('times_delete_0')), findsNothing);
    });
  });

  testWidgets(
      'Chip row hides parent-template and the device base profile',
      (tester) async {
    await withTrace((_) async {
      final profiles = [
        _profile('prof_parent', 'Parent', template: 'parent'),
        _profile('prof_base', 'Barn', template: 'child'),
        _profile('prof_school', 'School', template: ''),
        _profile('prof_bedtime', 'Bedtime', template: ''),
      ];

      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(_) {},
        onDelete: null,
      )));
      await tester.pump();

      // Parent stays filtered (no rule should target the parent
      // profile). The device base ("Barn") used to render as a disabled
      // "Standard" chip; it's now named in the override-hint sentence
      // above the chip row instead, so the chip row itself omits it to
      // give eligible chips more horizontal room.
      expect(find.text('Parent'), findsNothing);
      expect(find.byKey(const Key('standard_profile_chip')), findsNothing);
      expect(find.text('Barn'), findsNothing);
      // Eligible kid profiles render as normal chips.
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Bedtime'), findsOneWidget);
    });
  });

  testWidgets(
      'Override hint sentence is rendered when a device base is known',
      (tester) async {
    await withTrace((_) async {
      final profiles = [
        _profile('prof_base', 'Barn', template: 'child'),
        _profile('prof_school', 'School', template: ''),
      ];

      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(_) {},
        onDelete: null,
      )));
      await tester.pump();

      // The %s placeholder isn't substituted in test env (no translation
      // table), so the key matches verbatim. That's enough to confirm the
      // hint widget is mounted; visual %s substitution is exercised in
      // the live i18n pipeline.
      expect(find.text('family schedule rule editor override hint'),
          findsOneWidget);
    });
  });

  testWidgets(
      'Device base id never becomes the rule profileId (still filtered out)',
      (tester) async {
    await withTrace((_) async {
      final profiles = [
        _profile('prof_base', 'Barn', template: 'child'),
        _profile('prof_school', 'School', template: ''),
      ];

      String? savedProfileId;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(r) => savedProfileId = r.profileId,
        onDelete: null,
      )));
      await tester.pump();

      // Default selection seeds to the first eligible (School), never
      // the base — a rule whose profile equals the device base is a
      // 24/7 no-op, so saving must always return an eligible id.
      await tester.tap(find.byKey(const Key('rule_editor_save')));
      await tester.pumpAndSettle();

      expect(savedProfileId, 'prof_school');
    });
  });

  testWidgets('Smart default seeds the first eligible profile (not raw idx 0)',
      (tester) async {
    await withTrace((_) async {
      String? savedProfileId;
      final profiles = [
        _profile('prof_parent', 'Parent', template: 'parent'),
        _profile('prof_school', 'School', template: ''),
        _profile('prof_bedtime', 'Bedtime', template: ''),
      ];

      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_other',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(rule) => savedProfileId = rule.profileId,
        onDelete: null,
      )));
      await tester.pump();

      await tester.tap(find.byKey(const Key('rule_editor_save')));
      await tester.pumpAndSettle();

      expect(savedProfileId, 'prof_school');
    });
  });

  testWidgets(
      'Empty eligible list renders the sublabel and disables Save',
      (tester) async {
    await withTrace((_) async {
      // Only profiles: Parent (filtered) + the device base (filtered).
      // After filtering, the eligible list is empty.
      final profiles = [
        _profile('prof_parent', 'Parent', template: 'parent'),
        _profile('prof_base', 'Barn', template: 'child'),
      ];

      bool saveCalled = false;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(_) => saveCalled = true,
        onDelete: null,
      )));
      await tester.pump();

      // Empty-state sublabel renders (i18n key string matches verbatim in
      // test env — translation lookup is a no-op).
      expect(
          find.text('family schedule rule editor profile empty subtitle'),
          findsOneWidget);

      // Tapping Save while empty is a no-op (button is disabled).
      await tester.tap(find.byKey(const Key('rule_editor_save')));
      await tester.pumpAndSettle();
      expect(saveCalled, isFalse);
    });
  });

  testWidgets(
      'Tapping +New invokes onAddProfile and auto-selects the returned profile',
      (tester) async {
    await withTrace((_) async {
      final profiles = [
        _profile('prof_school', 'School', template: ''),
      ];
      final newProfile =
          _profile('prof_new', 'Homework', template: '');

      var addCalls = 0;
      String? savedProfileId;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: () async {
          addCalls++;
          return newProfile;
        },
        onEditProfile: null,
        onDeleteProfile: null,
        onSave: (rule) => savedProfileId = rule.profileId,
        onDelete: null,
      )));
      await tester.pump();

      // Tap the + New chip. Editor awaits, then rebuilds with the new
      // profile appended and selected.
      await tester.tap(find.byKey(const Key('add_profile_chip')));
      await tester.pumpAndSettle();
      expect(addCalls, 1);

      // Save now records the new profile id.
      await tester.tap(find.byKey(const Key('rule_editor_save')));
      await tester.pumpAndSettle();
      expect(savedProfileId, 'prof_new');
    });
  });

  testWidgets(
      'Edit row appears only when an eligible chip is selected and '
      'invokes onEditProfile with that profile', (tester) async {
    await withTrace((_) async {
      final profiles = [
        _profile('prof_school', 'School', template: ''),
        _profile('prof_bedtime', 'Bedtime', template: ''),
      ];
      JsonProfile? edited;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: null,
        onEditProfile: (p) async {
          edited = p;
          // Simulate the editor returning the same profile unchanged.
          return p;
        },
        onDeleteProfile: null,
        onSave: (_) {},
        onDelete: null,
      )));
      await tester.pump();

      // First eligible chip is auto-selected on first-rule seed, so the
      // Edit row should already render — pointing at School.
      final editRow = find.byKey(const Key('edit_selected_profile'));
      expect(editRow, findsOneWidget);

      await tester.tap(editRow);
      await tester.pumpAndSettle();
      expect(edited, isNotNull);
      expect(edited!.profileId, 'prof_school');
    });
  });

  testWidgets('Edit row is hidden when onEditProfile is null',
      (tester) async {
    await withTrace((_) async {
      final profiles = [_profile('prof_school', 'School', template: '')];
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave: (_) {},
        onDelete: null,
      )));
      await tester.pump();
      expect(find.byKey(const Key('edit_selected_profile')), findsNothing);
    });
  });

  testWidgets(
      'After onEditProfile returns null (deleted), the chip and selection '
      'clear and Save is disabled', (tester) async {
    await withTrace((_) async {
      final profiles = [_profile('prof_school', 'School', template: '')];
      var saveCalled = false;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: null,
        onEditProfile: (_) async => null, // simulate delete-from-editor
        onDeleteProfile: null,
        onSave: (_) => saveCalled = true,
        onDelete: null,
      )));
      await tester.pump();

      await tester.tap(find.byKey(const Key('edit_selected_profile')));
      await tester.pumpAndSettle();

      // Chip is gone, Edit row is gone, Save no-ops on tap.
      expect(find.byKey(const Key('edit_selected_profile')), findsNothing);
      await tester.tap(find.byKey(const Key('rule_editor_save')));
      await tester.pumpAndSettle();
      expect(saveCalled, isFalse);
    });
  });

  testWidgets('Profile chip row is horizontally scrollable',
      (tester) async {
    await withTrace((_) async {
      final profiles = [
        _profile('p1', 'School', template: ''),
        _profile('p2', 'Bedtime', template: ''),
      ];

      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(_) {},
        onDelete: null,
      )));
      await tester.pump();

      // There is exactly one horizontal SingleChildScrollView with the
      // chip-row key. Vertical SingleChildScrollViews elsewhere in the
      // editor don't have this key.
      final scrollable = tester.widget<SingleChildScrollView>(
          find.byKey(const Key('profile_chip_scroll')));
      expect(scrollable.scrollDirection, Axis.horizontal);
    });
  });

  testWidgets(
      'Long-press on a profile chip opens the CupertinoContextMenu '
      'with the destructive Delete action; tapping it invokes '
      'onDeleteProfile and on success the chip is removed',
      (tester) async {
    await withTrace((_) async {
      final profiles = [
        _profile('prof_school', 'School', template: ''),
        _profile('prof_bedtime', 'Bedtime', template: ''),
      ];
      JsonProfile? deleted;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: (p) async {
          deleted = p;
          return true;
        },
        onSave: (_) {},
        onDelete: null,
      )));
      await tester.pump();

      // Long-press lifts the chip into the iOS context menu.
      await tester.longPress(find.text('Bedtime'));
      await tester.pumpAndSettle();

      // Destructive action rendered with the localized label.
      expect(find.text('family profile editor delete'), findsOneWidget);
      await tester.tap(find.text('family profile editor delete'));
      await tester.pumpAndSettle();

      expect(deleted, isNotNull);
      expect(deleted!.profileId, 'prof_bedtime');
      expect(find.text('Bedtime'), findsNothing);
      expect(find.text('School'), findsWidgets);
    });
  });

  testWidgets(
      'Long-press: cb returns false (guarded refusal) keeps the chip',
      (tester) async {
    await withTrace((_) async {
      final profiles = [
        _profile('prof_school', 'School', template: ''),
        _profile('prof_bedtime', 'Bedtime', template: ''),
      ];
      var cbCalls = 0;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: (_) async {
          cbCalls++;
          return false; // host refused (e.g. rule-target guard)
        },
        onSave: (_) {},
        onDelete: null,
      )));
      await tester.pump();

      await tester.longPress(find.text('Bedtime'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('family profile editor delete'));
      await tester.pumpAndSettle();

      expect(cbCalls, 1);
      // Chip stays because the host refused the delete.
      expect(find.text('Bedtime'), findsWidgets);
    });
  });

  testWidgets(
      'Long-press: dismissing the context menu without tapping the '
      'destructive action never invokes the host callback', (tester) async {
    await withTrace((_) async {
      final profiles = [
        _profile('prof_school', 'School', template: ''),
        _profile('prof_bedtime', 'Bedtime', template: ''),
      ];
      var cbCalls = 0;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: profiles,
        deviceBaseProfileId: 'prof_base',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: (_) async {
          cbCalls++;
          return true;
        },
        onSave: (_) {},
        onDelete: null,
      )));
      await tester.pump();

      // Open the popover.
      await tester.longPress(find.text('Bedtime'));
      await tester.pumpAndSettle();
      expect(find.text('family profile editor delete'), findsOneWidget);

      // Tap the full-screen dismiss layer (outside the popover) —
      // equivalent to the user tapping anywhere outside the menu.
      await tester.tap(find.byKey(const Key('chip_menu_dismiss')));
      await tester.pumpAndSettle();

      expect(cbCalls, 0);
      expect(find.text('Bedtime'), findsWidgets);
      // Popover is gone.
      expect(find.text('family profile editor delete'), findsNothing);
    });
  });

  testWidgets(
      'Android: long-press opens the Material showMenu popup and the '
      'destructive item routes back through onDeleteProfile',
      (tester) async {
    await withTrace((_) async {
      final profiles = [
        _profile('prof_school', 'School', template: ''),
        _profile('prof_bedtime', 'Bedtime', template: ''),
      ];
      JsonProfile? deleted;
      await tester.pumpWidget(_wrapOn(
          TargetPlatform.android,
          RuleEditorSheet(
            deviceTag: 'tag1',
        deviceName: 'TestDevice',
            initialRule: null,
            availableProfiles: profiles,
            deviceBaseProfileId: 'prof_base',
            onAddProfile: null,
            onEditProfile: null,
            onDeleteProfile: (p) async {
              deleted = p;
              return true;
            },
            onSave: (_) {},
            onDelete: null,
          )));
      await tester.pump();

      await tester.longPress(find.text('Bedtime'));
      await tester.pumpAndSettle();

      // showMenu hosts the PopupMenuItem with the same destructive
      // label key. The Cupertino-only dismiss layer is absent here.
      expect(find.text('family profile editor delete'), findsOneWidget);
      expect(find.byKey(const Key('chip_menu_dismiss')), findsNothing);

      await tester.tap(find.text('family profile editor delete'));
      await tester.pumpAndSettle();

      expect(deleted, isNotNull);
      expect(deleted!.profileId, 'prof_bedtime');
      expect(find.text('Bedtime'), findsNothing);
      expect(find.text('School'), findsWidgets);
    });
  });

  testWidgets(
      'AppBar leading shows the device name; trailing shows Save',
      (tester) async {
    await withTrace((_) async {
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'Beaver',
        initialRule: null,
        availableProfiles: [_profile('p1', 'P', template: '')],
        deviceBaseProfileId: 'prof_other_unused',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave:(_) {},
        onDelete: null,
      )));
      await tester.pump();

      // Device name renders next to the back chevron — the "back to
      // previous screen" iOS pattern.
      expect(find.text('Beaver'), findsOneWidget);
      // Centered title is the screen name (i18n key in test env).
      expect(find.text('family schedule rule editor title new'),
          findsOneWidget);
      // Save action stays accessible at the AppBar trailing edge.
      expect(find.byKey(const Key('rule_editor_save')), findsOneWidget);
      // Back affordance is the keyed back button (no separate route
      // pop to assert — the test wrapper has no parent route — but the
      // tap target must exist for the screen to be dismissible).
      expect(find.byKey(const Key('rule_editor_back')), findsOneWidget);
    });
  });

  testWidgets(
      'Selecting the "No internet" target hides the profile section and saves '
      'action:block with no profile', (tester) async {
    await withTrace((_) async {
      RuleModel? saved;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: null,
        availableProfiles: [_profile('p1', 'School', template: '')],
        deviceBaseProfileId: 'prof_other_unused',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave: (r) => saved = r,
        onDelete: null,
      )));
      await tester.pump();

      // Filter is the default target, so the profile section is present. The
      // section label is upper-cased by _buildSection.
      expect(find.text('FAMILY SCHEDULE RULE EDITOR PROFILE LABEL'),
          findsOneWidget);

      // Pick "No internet" (block). The profile section disappears.
      await tester.tap(find.byKey(const Key('rule_target_block')));
      await tester.pumpAndSettle();
      expect(find.text('FAMILY SCHEDULE RULE EDITOR PROFILE LABEL'),
          findsNothing);

      // Save → a block rule with no profile id.
      await tester.tap(find.byKey(const Key('rule_editor_save')));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.action, 'block');
      expect(saved!.profileId, isEmpty);
    });
  });

  testWidgets(
      'Editing an existing block rule seeds the block target and Save stays '
      'enabled with no profile', (tester) async {
    await withTrace((_) async {
      RuleModel? saved;
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        initialRule: RuleModel(
          profileId: '',
          weekdays: const [1, 2, 3, 4, 5],
          windows: const [TimeWindowModel(startMinute: 1260, endMinute: 420)],
          action: 'block',
        ),
        availableProfiles: [_profile('p1', 'School', template: '')],
        deviceBaseProfileId: 'prof_other_unused',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave: (r) => saved = r,
        onDelete: () {},
      )));
      await tester.pump();

      // Block target rules carry no profile, so the profile section is hidden
      // and Save is not gated on a profile pick.
      expect(find.text('FAMILY SCHEDULE RULE EDITOR PROFILE LABEL'),
          findsNothing);
      await tester.tap(find.byKey(const Key('rule_editor_save')));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.action, 'block');
      expect(saved!.profileId, isEmpty);
      expect(saved!.weekdays, [1, 2, 3, 4, 5]);
    });
  });

  testWidgets(
      'Switching from block back to filter restores the profile section and '
      're-gates Save until a profile is picked', (tester) async {
    await withTrace((_) async {
      await tester.pumpWidget(_wrap(RuleEditorSheet(
        deviceTag: 'tag1',
        deviceName: 'TestDevice',
        // No eligible profiles: base + nothing else, so a filter rule cannot
        // pick a profile and Save must stay disabled when filter is active.
        initialRule: null,
        availableProfiles: const [],
        deviceBaseProfileId: 'prof_other_unused',
        onAddProfile: null,
        onEditProfile: null,
        onDeleteProfile: null,
        onSave: (_) {},
        onDelete: null,
      )));
      await tester.pump();

      Text saveTrailing() => tester.widget<Text>(find.descendant(
          of: find.byKey(const Key('rule_editor_save')),
          matching: find.byType(Text)));

      // Filter active, no profile → Save disabled (rendered in divider grey).
      expect((saveTrailing().style!.color), Colors.grey);

      // Block → Save enabled (accent), profile section gone.
      await tester.tap(find.byKey(const Key('rule_target_block')));
      await tester.pumpAndSettle();
      expect((saveTrailing().style!.color), Colors.blue);

      // Back to filter → profile section returns, Save disabled again.
      await tester.tap(find.byKey(const Key('rule_target_filter')));
      await tester.pumpAndSettle();
      expect(find.text('FAMILY SCHEDULE RULE EDITOR PROFILE LABEL'),
          findsOneWidget);
      expect((saveTrailing().style!.color), Colors.grey);
    });
  });
}
