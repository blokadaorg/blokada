import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeWindowModel', () {
    test('round-trips through JSON preserving minutes', () {
      final w = TimeWindowModel(startMinute: 510, endMinute: 900);
      final json = w.toJson();
      expect(json, {'start_minute': 510, 'end_minute': 900});

      final restored = TimeWindowModel.fromJson(json);
      expect(restored.startMinute, 510);
      expect(restored.endMinute, 900);
    });

    test('wraparound window (end < start) is preserved as-is', () {
      final w = TimeWindowModel(startMinute: 1260, endMinute: 420);
      expect(w.wrapsToNextDay, isTrue);
      expect(w.toJson(), {'start_minute': 1260, 'end_minute': 420});
    });

    test('non-wraparound window reports wrapsToNextDay false', () {
      final w = TimeWindowModel(startMinute: 510, endMinute: 900);
      expect(w.wrapsToNextDay, isFalse);
    });
  });

  group('RuleModel', () {
    test('round-trips a single-window rule', () {
      final rule = RuleModel(
        profileId: 'prof_school',
        weekdays: const [1, 2, 3, 4, 5],
        windows: const [
          TimeWindowModel(startMinute: 480, endMinute: 900),
        ],
      );
      final json = rule.toJson();
      expect(json, {
        'profile_id': 'prof_school',
        'weekdays': [1, 2, 3, 4, 5],
        'windows': [
          {'start_minute': 480, 'end_minute': 900},
        ],
      });
      final restored = RuleModel.fromJson(json);
      expect(restored.profileId, 'prof_school');
      expect(restored.weekdays, [1, 2, 3, 4, 5]);
      expect(restored.windows, hasLength(1));
      expect(restored.windows.first.startMinute, 480);
    });

    test('round-trips multi-window rule preserving order', () {
      final rule = RuleModel(
        profileId: 'prof_school',
        weekdays: const [1, 2, 3, 4, 5],
        windows: const [
          TimeWindowModel(startMinute: 510, endMinute: 720),
          TimeWindowModel(startMinute: 780, endMinute: 930),
        ],
      );
      final restored = RuleModel.fromJson(rule.toJson());
      expect(restored.windows.map((w) => w.startMinute), [510, 780]);
    });

    test('canonicalises weekdays sorted ascending on construction', () {
      final rule = RuleModel(
        profileId: 'prof',
        weekdays: const [7, 1, 3],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
      );
      expect(rule.weekdays, [1, 3, 7]);
    });
  });

  group('ScheduleModel', () {
    // Per coordinator plan §"Wire format" amendment (2026-05-15):
    // `default_profile_id` is REMOVED. ScheduleModel has only `paused` and
    // `rules`. The Default is the device's existing `profile_id` field.
    test('round-trips empty rules + paused false', () {
      final s = ScheduleModel(paused: false, rules: const []);
      final json = s.toJson();
      expect(json, {
        'paused': false,
        'rules': <Map<String, dynamic>>[],
      });
      final restored = ScheduleModel.fromJson(json);
      expect(restored.paused, isFalse);
      expect(restored.rules, isEmpty);
    });

    test('round-trips paused + wraparound bedtime rule', () {
      final s = ScheduleModel(
        paused: true,
        rules: [
          RuleModel(
            profileId: 'prof_bedtime',
            weekdays: const [1, 2, 3, 4, 5, 6, 7],
            windows: const [
              TimeWindowModel(startMinute: 1260, endMinute: 420),
            ],
          ),
        ],
      );
      final restored = ScheduleModel.fromJson(s.toJson());
      expect(restored.paused, isTrue);
      expect(restored.rules, hasLength(1));
      expect(restored.rules.first.windows.first.wrapsToNextDay, isTrue);
    });

    test('preserves rule list order on round-trip', () {
      final s = ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: 'prof_a',
            weekdays: const [1],
            windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
          ),
          RuleModel(
            profileId: 'prof_b',
            weekdays: const [2],
            windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
          ),
        ],
      );
      final restored = ScheduleModel.fromJson(s.toJson());
      expect(restored.rules.map((r) => r.profileId), ['prof_a', 'prof_b']);
    });

    test('validate rejects empty weekdays', () {
      final s = ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: 'prof_a',
            weekdays: const [],
            windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
          ),
        ],
      );
      expect(
        () => s.validate(profileIds: const {'prof_a'}),
        throwsA(isA<ScheduleValidationError>()
            .having((e) => e.code, 'code', 'empty_weekdays')),
      );
    });

    test('validate rejects empty windows', () {
      final s = ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: 'prof_a',
            weekdays: const [1],
            windows: const [],
          ),
        ],
      );
      expect(
        () => s.validate(profileIds: const {'prof_a'}),
        throwsA(isA<ScheduleValidationError>()
            .having((e) => e.code, 'code', 'empty_windows')),
      );
    });

    test('validate rejects more than 4 windows on a single rule', () {
      const w = TimeWindowModel(startMinute: 0, endMinute: 30);
      final s = ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: 'prof_a',
            weekdays: const [1],
            windows: List.filled(5, w),
          ),
        ],
      );
      expect(
        () => s.validate(profileIds: const {'prof_a'}),
        throwsA(isA<ScheduleValidationError>()
            .having((e) => e.code, 'code', 'too_many_windows')),
      );
    });

    test('validate rejects start == end window', () {
      final s = ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: 'prof_a',
            weekdays: const [1],
            windows: const [
              TimeWindowModel(startMinute: 600, endMinute: 600),
            ],
          ),
        ],
      );
      expect(
        () => s.validate(profileIds: const {'prof_a'}),
        throwsA(isA<ScheduleValidationError>()
            .having((e) => e.code, 'code', 'zero_length_window')),
      );
    });

    test('validate rejects unknown rule profile_id', () {
      final s = ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: 'prof_missing',
            weekdays: const [1],
            windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
          ),
        ],
      );
      expect(
        () => s.validate(profileIds: const {'prof_default'}),
        throwsA(isA<ScheduleValidationError>()
            .having((e) => e.code, 'code', 'unknown_rule_profile')),
      );
    });

    test('validate rejects weekday outside [1, 7]', () {
      final s = ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: 'prof_a',
            weekdays: const [0, 1],
            windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
          ),
        ],
      );
      expect(
        () => s.validate(profileIds: const {'prof_a'}),
        throwsA(isA<ScheduleValidationError>()
            .having((e) => e.code, 'code', 'invalid_weekday')),
      );
    });

    test('validate accepts a fully valid schedule', () {
      final s = ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: 'prof_a',
            weekdays: const [1, 2, 3, 4, 5],
            windows: const [
              TimeWindowModel(startMinute: 510, endMinute: 720),
              TimeWindowModel(startMinute: 780, endMinute: 900),
            ],
          ),
        ],
      );
      expect(
        () => s.validate(profileIds: const {'prof_a'}),
        returnsNormally,
      );
    });
  });

  group('JsonDevice schedule + timezone fields', () {
    test('parses schedule and timezone when api returns them', () {
      final json = {
        'device_tag': 'tag1',
        'alias': 'Kid Phone',
        'mode': 'on',
        'retention': '24h',
        'profile_id': 'prof_default',
        'last_heartbeat': '2026-05-15T10:00:00Z',
        'timezone': 'Europe/Stockholm',
        'schedule': {
          'paused': false,
          'rules': [
            {
              'profile_id': 'prof_school',
              'weekdays': [1, 2, 3, 4, 5],
              'windows': [
                {'start_minute': 480, 'end_minute': 900}
              ]
            }
          ]
        }
      };
      final d = JsonDevice.fromJson(json);
      expect(d.schedule, isNotNull);
      expect(d.schedule!.paused, isFalse);
      expect(d.schedule!.rules, hasLength(1));
      expect(d.timezone, 'Europe/Stockholm');
    });

    test('schedule and timezone are null when api omits them (legacy)', () {
      // Per coordinator plan: the wire format is purely additive. Legacy
      // devices with no schedule and no timezone parse without error;
      // both fields are null. The Default remains the device's top-level
      // profile_id, unchanged from today.
      final json = {
        'device_tag': 'tag1',
        'alias': 'Kid Phone',
        'mode': 'on',
        'retention': '24h',
        'profile_id': 'prof_legacy',
        'last_heartbeat': '2026-05-15T10:00:00Z',
      };
      final d = JsonDevice.fromJson(json);
      expect(d.schedule, isNull);
      expect(d.timezone, isNull);
      expect(d.profileId, 'prof_legacy');
    });

    test('toJson omits schedule and timezone when null', () {
      final d = JsonDevice(
        deviceTag: 'tag1',
        alias: 'Kid Phone',
        mode: JsonDeviceMode.on,
        retention: '24h',
        profileId: 'prof_legacy',
      );
      d.lastHeartbeat = '2026-05-15T10:00:00Z';
      final out = d.toJson();
      expect(out.containsKey('schedule'), isFalse);
      expect(out.containsKey('timezone'), isFalse);
    });

    test('toJson emits schedule and timezone when present', () {
      final d = JsonDevice(
        deviceTag: 'tag1',
        alias: 'Kid Phone',
        mode: JsonDeviceMode.on,
        retention: '24h',
        profileId: 'prof_default',
        schedule:
            const ScheduleModel(paused: true, rules: <RuleModel>[]),
        timezone: 'Europe/Stockholm',
      );
      d.lastHeartbeat = '2026-05-15T10:00:00Z';
      final out = d.toJson();
      expect(out['schedule'], {'paused': true, 'rules': <dynamic>[]});
      expect(out['timezone'], 'Europe/Stockholm');
    });
  });
}
