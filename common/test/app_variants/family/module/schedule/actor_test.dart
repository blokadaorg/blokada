import 'package:common/src/app_variants/family/module/schedule/actor.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScheduleActor pure transforms', () {
    const base = ScheduleModel(paused: false, rules: <RuleModel>[]);

    test('setPaused flips the flag without touching rules', () {
      final result = ScheduleActor.setPaused(base, true);
      expect(result.paused, isTrue);
      expect(result.rules, base.rules);
    });

    test('addRule appends to the end (list order is significant)', () {
      final rule = RuleModel(
        profileId: 'prof_school',
        weekdays: const [1, 2, 3, 4, 5],
        windows: const [TimeWindowModel(startMinute: 480, endMinute: 900)],
      );
      final result = ScheduleActor.addRule(base, rule);
      expect(result.rules, hasLength(1));
      expect(result.rules.first.profileId, 'prof_school');
    });

    test('updateRule replaces the entry at the matching index', () {
      final r1 = RuleModel(
        profileId: 'prof_a',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
      );
      final r2 = RuleModel(
        profileId: 'prof_b',
        weekdays: const [2],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
      );
      final s = ScheduleActor.addRule(ScheduleActor.addRule(base, r1), r2);
      final replaced = RuleModel(
        profileId: 'prof_a',
        weekdays: const [1, 2],
        windows: const [TimeWindowModel(startMinute: 120, endMinute: 180)],
      );
      final result = ScheduleActor.updateRule(s, 0, replaced);
      expect(result.rules.first.weekdays, [1, 2]);
      expect(result.rules.last.profileId, 'prof_b');
    });

    test('deleteRule removes at the index, preserves order of the rest', () {
      final r1 = RuleModel(
        profileId: 'prof_a',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
      );
      final r2 = RuleModel(
        profileId: 'prof_b',
        weekdays: const [2],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
      );
      final r3 = RuleModel(
        profileId: 'prof_c',
        weekdays: const [3],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
      );
      final s = ScheduleActor.addRule(
          ScheduleActor.addRule(ScheduleActor.addRule(base, r1), r2), r3);
      final result = ScheduleActor.deleteRule(s, 1);
      expect(result.rules.map((r) => r.profileId), ['prof_a', 'prof_c']);
    });

    test(
        'reorderRules follows ReorderableListView.onReorder semantics '
        '(newIndex is the pre-removal slot when moving down)', () {
      final r1 = RuleModel(
        profileId: 'prof_a',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
      );
      final r2 = RuleModel(
        profileId: 'prof_b',
        weekdays: const [2],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
      );
      final r3 = RuleModel(
        profileId: 'prof_c',
        weekdays: const [3],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
      );
      final s = ScheduleActor.addRule(
          ScheduleActor.addRule(ScheduleActor.addRule(base, r1), r2), r3);

      // Move index 0 → index 3 (oldIndex < newIndex, so the helper compresses
      // the destination to newIndex-1 = 2, matching framework convention).
      final result = ScheduleActor.reorderRules(s, 0, 3);
      expect(result.rules.map((r) => r.profileId),
          ['prof_b', 'prof_c', 'prof_a']);
    });
  });
}
