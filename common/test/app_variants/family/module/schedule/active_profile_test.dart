import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dart port of `blockarust/src/schedule.rs::active_profile_for_schedule`
/// unit tests. The resolver works on the wall-clock fields of the supplied
/// `DateTime` (weekday / hour / minute), so the tests construct plain local
/// `DateTime`s and assert the firing rule's `profileId` + matched window end,
/// mirroring the Rust cases 1:1.
void main() {
  // 08:30–15:00 (510..900), Mon–Fri.
  RuleModel schoolRule() => RuleModel(
        profileId: 'school',
        weekdays: const [1, 2, 3, 4, 5],
        windows: const [TimeWindowModel(startMinute: 510, endMinute: 900)],
      );

  // 21:00–07:00 (1260..420, wraps), every day.
  RuleModel bedtimeRule() => RuleModel(
        profileId: 'bedtime',
        weekdays: const [1, 2, 3, 4, 5, 6, 7],
        windows: const [TimeWindowModel(startMinute: 1260, endMinute: 420)],
      );

  ScheduleModel sched(List<RuleModel> rules, bool paused) =>
      ScheduleModel(paused: paused, rules: rules);

  // Wall-clock DateTime; year/month/day picked so DateTime.weekday matches the
  // Rust fixtures (2026-05-11 is a Monday).
  DateTime dt(int y, int mo, int d, int h, int mi) => DateTime(y, mo, d, h, mi);

  test('paused schedule returns null', () {
    final s = sched([schoolRule(), bedtimeRule()], true);
    final now = dt(2026, 5, 13, 10, 0); // Wed 10:00 — would match school
    expect(activeRuleForSchedule(s, now), isNull);
  });

  test('empty rules returns null', () {
    final s = sched(const [], false);
    final now = dt(2026, 5, 13, 10, 0);
    expect(activeRuleForSchedule(s, now), isNull);
  });

  test('weekday match inside window returns rule + window end', () {
    final s = sched([schoolRule()], false);
    final now = dt(2026, 5, 13, 10, 0); // Wed 10:00 in [08:30, 15:00)
    final active = activeRuleForSchedule(s, now);
    expect(active, isNotNull);
    expect(active!.rule.profileId, 'school');
    expect(active.ruleIndex, 0);
    expect(active.endMinute, 900); // 15:00
  });

  test('weekday match before window returns null', () {
    final s = sched([schoolRule()], false);
    final now = dt(2026, 5, 13, 8, 0); // Wed 08:00, before 08:30
    expect(activeRuleForSchedule(s, now), isNull);
  });

  test('weekday match at window end is exclusive', () {
    final s = sched([schoolRule()], false);
    final atEnd = dt(2026, 5, 13, 15, 0); // 15:00 == endMinute 900
    expect(activeRuleForSchedule(s, atEnd), isNull);
  });

  test('off weekday returns null', () {
    final s = sched([schoolRule()], false);
    // Saturday 2026-05-16 at 10:00 — school's weekdays don't include 6.
    final now = dt(2026, 5, 16, 10, 0);
    expect(activeRuleForSchedule(s, now), isNull);
  });

  test('wraparound window late evening matches', () {
    final s = sched([bedtimeRule()], false);
    final now = dt(2026, 5, 11, 22, 30); // Mon 22:30
    final active = activeRuleForSchedule(s, now);
    expect(active, isNotNull);
    expect(active!.rule.profileId, 'bedtime');
    expect(active.endMinute, 420); // 07:00 next day
  });

  test('wraparound window early morning matches', () {
    final s = sched([bedtimeRule()], false);
    final now = dt(2026, 5, 12, 6, 30); // Tue 06:30
    final active = activeRuleForSchedule(s, now);
    expect(active, isNotNull);
    expect(active!.rule.profileId, 'bedtime');
  });

  test('wraparound window midday does not match', () {
    final s = sched([bedtimeRule()], false);
    final now = dt(2026, 5, 12, 12, 0); // Tue noon
    expect(activeRuleForSchedule(s, now), isNull);
  });

  test('single-weekday wrap rule matches its next-day early-morning tail', () {
    // 21:00–07:00 starting Friday only. Sat 02:00 is the carry-over tail and
    // must still fire even though Saturday (ISO 6) is not in weekdays=[5].
    // Mirrors resolver_test's "wraparound window carries into early morning".
    final fridayBedtime = RuleModel(
      profileId: 'bedtime',
      weekdays: const [5], // Friday start only.
      windows: const [TimeWindowModel(startMinute: 1260, endMinute: 420)],
    );
    final s = sched([fridayBedtime], false);
    // 2026-05-15 is a Friday; 2026-05-16 02:00 is Saturday 02:00 (ISO 6).
    final satTail = dt(2026, 5, 16, 2, 0);
    final active = activeRuleForSchedule(s, satTail);
    expect(active, isNotNull);
    expect(active!.rule.profileId, 'bedtime');
    expect(active.endMinute, 420); // until 07:00 Saturday.
  });

  test('single-weekday wrap rule does not match two days later', () {
    // Same Friday-only bedtime rule: Sunday 02:00 is two days past the start,
    // outside both the Friday evening half and the Saturday carry-over tail.
    final fridayBedtime = RuleModel(
      profileId: 'bedtime',
      weekdays: const [5],
      windows: const [TimeWindowModel(startMinute: 1260, endMinute: 420)],
    );
    final s = sched([fridayBedtime], false);
    final sunTail = dt(2026, 5, 17, 2, 0); // Sunday 02:00 (ISO 7).
    expect(activeRuleForSchedule(s, sunTail), isNull);
  });

  test('non-wrap single-day rule is unaffected by carry-over logic', () {
    // A same-day window only matches on its own weekday; the previous day must
    // not leak in via the wrap branch.
    final fridaySchool = RuleModel(
      profileId: 'school',
      weekdays: const [5], // Friday only.
      windows: const [TimeWindowModel(startMinute: 510, endMinute: 900)],
    );
    final s = sched([fridaySchool], false);
    // Friday 10:00 matches; Saturday 10:00 (carry-over day) must not.
    expect(
      activeRuleForSchedule(s, dt(2026, 5, 15, 10, 0))!.rule.profileId,
      'school',
    );
    expect(activeRuleForSchedule(s, dt(2026, 5, 16, 10, 0)), isNull);
  });

  test('list order wins on overlap (different windows)', () {
    final s = sched([schoolRule(), bedtimeRule()], false);
    final schoolHours = dt(2026, 5, 11, 10, 0); // Mon 10:00
    final evening = dt(2026, 5, 11, 21, 30); // Mon 21:30
    expect(activeRuleForSchedule(s, schoolHours)!.rule.profileId, 'school');
    expect(activeRuleForSchedule(s, evening)!.rule.profileId, 'bedtime');
  });

  test('list order wins when two rules match simultaneously', () {
    final ruleA = RuleModel(
      profileId: 'first',
      weekdays: const [1],
      windows: const [TimeWindowModel(startMinute: 480, endMinute: 720)],
    ); // 08:00–12:00
    final ruleB = RuleModel(
      profileId: 'second',
      weekdays: const [1],
      windows: const [TimeWindowModel(startMinute: 540, endMinute: 660)],
    ); // 09:00–11:00
    final s = sched([ruleA, ruleB], false);
    final now = dt(2026, 5, 11, 10, 0); // Mon — inside both windows
    final active = activeRuleForSchedule(s, now);
    expect(active!.rule.profileId, 'first');
    expect(active.ruleIndex, 0);
  });

  test('weekday matrix: each ISO day matches exactly its rule', () {
    for (var iso = 1; iso <= 7; iso++) {
      final r = RuleModel(
        profileId: 'p$iso',
        weekdays: [iso],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 1439)],
      );
      final s = sched([r], false);
      // 2026-05-11 is Monday (ISO 1); add (iso-1) days.
      final day = DateTime(2026, 5, 11).add(Duration(days: iso - 1));
      final now = DateTime(day.year, day.month, day.day, 12, 0);
      expect(activeRuleForSchedule(s, now)!.rule.profileId, 'p$iso');
    }
  });

  test('rule with empty windows never matches', () {
    final r = RuleModel(
      profileId: 'never',
      weekdays: const [3],
      windows: const [],
    );
    final s = sched([r], false);
    final now = dt(2026, 5, 13, 10, 0); // Wed
    expect(activeRuleForSchedule(s, now), isNull);
  });

  test('zero-length window never matches', () {
    final r = RuleModel(
      profileId: 'never',
      weekdays: const [3],
      windows: const [TimeWindowModel(startMinute: 600, endMinute: 600)],
    );
    final s = sched([r], false);
    final now = dt(2026, 5, 13, 10, 0); // Wed 10:00 == start == end
    expect(activeRuleForSchedule(s, now), isNull);
  });
}
