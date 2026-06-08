import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/schedule/resolver.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

JsonDevice _device({
  JsonDeviceMode mode = JsonDeviceMode.on,
  DateTime? modeUntil,
  ScheduleModel? schedule,
  String profileId = 'prof_default',
}) {
  final d = JsonDevice(
    deviceTag: 'tag',
    alias: 'Kid Phone',
    mode: mode,
    retention: '24h',
    profileId: profileId,
    modeUntil: modeUntil,
    schedule: schedule,
    timezone: 'Europe/Stockholm',
  );
  d.lastHeartbeat = '2026-05-15T10:00:00Z';
  return d;
}

// Mon 2026-06-08 09:00 local wall-clock. Dart weekday == 1 (Monday).
final _monMorning = DateTime(2026, 6, 8, 9, 0);

void main() {
  group('resolveEffectiveState — manual override precedence', () {
    test('active indefinite block override wins over a matching rule', () {
      final s = ScheduleModel(paused: false, rules: [
        RuleModel(
          profileId: 'prof_school',
          weekdays: const [1],
          windows: const [TimeWindowModel(startMinute: 480, endMinute: 900)],
        ),
      ]);
      final r = resolveEffectiveState(
        _device(mode: JsonDeviceMode.blocked, schedule: s),
        _monMorning,
      );
      expect(r.source, EffectiveSource.manualOverride);
      expect(r.outcome, EffectiveOutcome.blocked);
      expect(r.blocked, isTrue);
      expect(r.profileId, isNull);
      expect(r.until, isNull);
    });

    test('off override resolves to allowAll with no profile', () {
      final r = resolveEffectiveState(
        _device(mode: JsonDeviceMode.off),
        _monMorning,
      );
      expect(r.source, EffectiveSource.manualOverride);
      expect(r.outcome, EffectiveOutcome.allowAll);
      expect(r.profileId, isNull);
    });

    test('bounded override active before its until surfaces the until', () {
      final until = _monMorning.add(const Duration(hours: 2));
      final r = resolveEffectiveState(
        _device(mode: JsonDeviceMode.off, modeUntil: until),
        _monMorning,
      );
      expect(r.source, EffectiveSource.manualOverride);
      expect(r.until, until);
    });

    test('expired override falls through (mode stale, modeUntil in the past)',
        () {
      // mode is still `off` on the record, but modeUntil already passed, so
      // the override is no longer active and the default applies.
      final until = _monMorning.subtract(const Duration(minutes: 1));
      final r = resolveEffectiveState(
        _device(mode: JsonDeviceMode.off, modeUntil: until),
        _monMorning,
      );
      expect(r.source, EffectiveSource.deviceDefault);
      expect(r.outcome, EffectiveOutcome.filter);
      expect(r.profileId, 'prof_default');
    });

    test('mode on is never an override regardless of modeUntil', () {
      final r = resolveEffectiveState(
        _device(
          mode: JsonDeviceMode.on,
          modeUntil: _monMorning.add(const Duration(hours: 1)),
        ),
        _monMorning,
      );
      expect(r.source, EffectiveSource.deviceDefault);
    });
  });

  group('resolveEffectiveState — schedule rules', () {
    test('a matching filter rule applies its profile', () {
      final s = ScheduleModel(paused: false, rules: [
        RuleModel(
          profileId: 'prof_school',
          weekdays: const [1, 2, 3, 4, 5],
          windows: const [TimeWindowModel(startMinute: 480, endMinute: 900)],
        ),
      ]);
      final r = resolveEffectiveState(_device(schedule: s), _monMorning);
      expect(r.source, EffectiveSource.scheduleRule);
      expect(r.outcome, EffectiveOutcome.filter);
      expect(r.profileId, 'prof_school');
    });

    test('a matching block rule blocks with no profile', () {
      final s = ScheduleModel(paused: false, rules: [
        RuleModel(
          profileId: '',
          weekdays: const [1],
          windows: const [TimeWindowModel(startMinute: 480, endMinute: 900)],
          action: 'block',
        ),
      ]);
      final r = resolveEffectiveState(_device(schedule: s), _monMorning);
      expect(r.source, EffectiveSource.scheduleRule);
      expect(r.outcome, EffectiveOutcome.blocked);
      expect(r.profileId, isNull);
    });

    test('a paused schedule is ignored and the default applies', () {
      final s = ScheduleModel(paused: true, rules: [
        RuleModel(
          profileId: 'prof_school',
          weekdays: const [1],
          windows: const [TimeWindowModel(startMinute: 480, endMinute: 900)],
        ),
      ]);
      final r = resolveEffectiveState(_device(schedule: s), _monMorning);
      expect(r.source, EffectiveSource.deviceDefault);
      expect(r.profileId, 'prof_default');
    });

    test('first matching rule wins by list order', () {
      final s = ScheduleModel(paused: false, rules: [
        RuleModel(
          profileId: 'prof_first',
          weekdays: const [1],
          windows: const [TimeWindowModel(startMinute: 0, endMinute: 1439)],
        ),
        RuleModel(
          profileId: 'prof_second',
          weekdays: const [1],
          windows: const [TimeWindowModel(startMinute: 0, endMinute: 1439)],
        ),
      ]);
      final r = resolveEffectiveState(_device(schedule: s), _monMorning);
      expect(r.profileId, 'prof_first');
    });

    test('outside the window falls through to default', () {
      final s = ScheduleModel(paused: false, rules: [
        RuleModel(
          profileId: 'prof_school',
          weekdays: const [1],
          // 08:00–09:00; 09:00 is exclusive end, so not matched at 09:00.
          windows: const [TimeWindowModel(startMinute: 480, endMinute: 540)],
        ),
      ]);
      final r = resolveEffectiveState(_device(schedule: s), _monMorning);
      expect(r.source, EffectiveSource.deviceDefault);
    });

    test('wrong weekday falls through to default', () {
      final s = ScheduleModel(paused: false, rules: [
        RuleModel(
          profileId: 'prof_school',
          weekdays: const [2], // Tuesday only; now is Monday.
          windows: const [TimeWindowModel(startMinute: 0, endMinute: 1439)],
        ),
      ]);
      final r = resolveEffectiveState(_device(schedule: s), _monMorning);
      expect(r.source, EffectiveSource.deviceDefault);
    });

    test('wraparound bedtime window matches late evening on its start day', () {
      // 21:00–07:00 on Monday: 22:00 Monday is inside.
      final s = ScheduleModel(paused: false, rules: [
        RuleModel(
          profileId: 'prof_bedtime',
          weekdays: const [1],
          windows: const [TimeWindowModel(startMinute: 1260, endMinute: 420)],
        ),
      ]);
      final monNight = DateTime(2026, 6, 8, 22, 0);
      final r = resolveEffectiveState(_device(schedule: s), monNight);
      expect(r.source, EffectiveSource.scheduleRule);
      expect(r.profileId, 'prof_bedtime');
    });

    test('wraparound window carries into early morning of the next day', () {
      // 21:00–07:00 starting Monday: 06:00 Tuesday is still inside.
      final s = ScheduleModel(paused: false, rules: [
        RuleModel(
          profileId: 'prof_bedtime',
          weekdays: const [1], // Monday start only.
          windows: const [TimeWindowModel(startMinute: 1260, endMinute: 420)],
        ),
      ]);
      final tueMorning = DateTime(2026, 6, 9, 6, 0); // Tuesday 06:00.
      final r = resolveEffectiveState(_device(schedule: s), tueMorning);
      expect(r.source, EffectiveSource.scheduleRule);
      expect(r.profileId, 'prof_bedtime');
    });
  });

  group('resolveEffectiveState — default fallthrough', () {
    test('no schedule at all resolves to the device default', () {
      final r = resolveEffectiveState(_device(), _monMorning);
      expect(r.source, EffectiveSource.deviceDefault);
      expect(r.outcome, EffectiveOutcome.filter);
      expect(r.profileId, 'prof_default');
      expect(r.until, isNull);
    });
  });
}
