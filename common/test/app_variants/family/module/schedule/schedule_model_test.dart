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

    test('action absent on the wire round-trips as null (filter default)', () {
      final json = {
        'profile_id': 'prof_school',
        'weekdays': [1],
        'windows': [
          {'start_minute': 0, 'end_minute': 60}
        ],
      };
      final restored = RuleModel.fromJson(json);
      expect(restored.action, isNull);
      // toJson must NOT re-emit the key for a filter/null action.
      expect(restored.toJson().containsKey('action'), isFalse);
    });

    test('action "filter" round-trips and is emitted', () {
      final rule = RuleModel(
        profileId: 'prof_school',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
        action: 'filter',
      );
      final json = rule.toJson();
      expect(json['action'], 'filter');
      expect(RuleModel.fromJson(json).action, 'filter');
    });

    test('action "block" round-trips with empty profile_id', () {
      final rule = RuleModel(
        profileId: '',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
        action: 'block',
      );
      final json = rule.toJson();
      expect(json['action'], 'block');
      expect(json['profile_id'], '');
      final restored = RuleModel.fromJson(json);
      expect(restored.action, 'block');
      expect(restored.profileId, '');
    });

    test('copyWith preserves action when not overridden', () {
      final rule = RuleModel(
        profileId: '',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
        action: 'block',
      );
      expect(rule.copyWith(weekdays: const [2]).action, 'block');
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

    ScheduleModel single(RuleModel rule) =>
        ScheduleModel(paused: false, rules: [rule]);

    test('validate accepts a block rule with empty profile_id', () {
      final s = single(RuleModel(
        profileId: '',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
        action: 'block',
      ));
      // No profile reference, so the profile set is irrelevant.
      expect(() => s.validate(profileIds: const {}), returnsNormally);
    });

    test('validate rejects a block rule that carries a profile_id', () {
      final s = single(RuleModel(
        profileId: 'prof_a',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
        action: 'block',
      ));
      expect(
        () => s.validate(profileIds: const {'prof_a'}),
        throwsA(isA<ScheduleValidationError>()
            .having((e) => e.code, 'code', 'block_rule_with_profile')),
      );
    });

    test('validate rejects a filter rule with empty profile_id', () {
      final s = single(RuleModel(
        profileId: '',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
        action: 'filter',
      ));
      expect(
        () => s.validate(profileIds: const {'prof_a'}),
        throwsA(isA<ScheduleValidationError>()
            .having((e) => e.code, 'code', 'filter_rule_without_profile')),
      );
    });

    test('validate rejects a rule with empty profile_id and null action', () {
      // Null action defaults to filter, so the same profile requirement holds.
      final s = single(RuleModel(
        profileId: '',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
      ));
      expect(
        () => s.validate(profileIds: const {'prof_a'}),
        throwsA(isA<ScheduleValidationError>()
            .having((e) => e.code, 'code', 'filter_rule_without_profile')),
      );
    });

    test('validate rejects an unknown action value', () {
      final s = single(RuleModel(
        profileId: 'prof_a',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
        action: 'allow',
      ));
      expect(
        () => s.validate(profileIds: const {'prof_a'}),
        throwsA(isA<ScheduleValidationError>()
            .having((e) => e.code, 'code', 'invalid_rule_action')),
      );
    });

    test('validate accepts an explicit filter action with a known profile', () {
      final s = single(RuleModel(
        profileId: 'prof_a',
        weekdays: const [1],
        windows: const [TimeWindowModel(startMinute: 0, endMinute: 60)],
        action: 'filter',
      ));
      expect(() => s.validate(profileIds: const {'prof_a'}), returnsNormally);
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

  group('JsonDevice mode_until field', () {
    test('parses mode_until as a UTC instant', () {
      final json = {
        'device_tag': 'tag1',
        'alias': 'Kid Phone',
        'mode': 'off',
        'retention': '24h',
        'profile_id': 'prof_default',
        'last_heartbeat': '2026-05-15T10:00:00Z',
        'mode_until': '2026-06-08T21:00:00Z',
      };
      final d = JsonDevice.fromJson(json);
      expect(d.modeUntil, DateTime.utc(2026, 6, 8, 21, 0, 0));
      expect(d.modeUntil!.isUtc, isTrue);
    });

    test('mode_until is null when the api omits it (legacy / indefinite)', () {
      final json = {
        'device_tag': 'tag1',
        'alias': 'Kid Phone',
        'mode': 'on',
        'retention': '24h',
        'profile_id': 'prof_default',
        'last_heartbeat': '2026-05-15T10:00:00Z',
      };
      expect(JsonDevice.fromJson(json).modeUntil, isNull);
    });

    test('toJson omits mode_until when null', () {
      final d = JsonDevice(
        deviceTag: 'tag1',
        alias: 'Kid Phone',
        mode: JsonDeviceMode.on,
        retention: '24h',
        profileId: 'prof_default',
      );
      d.lastHeartbeat = '2026-05-15T10:00:00Z';
      expect(d.toJson().containsKey('mode_until'), isFalse);
    });

    test('toJson emits mode_until as RFC3339 UTC when set', () {
      final d = JsonDevice(
        deviceTag: 'tag1',
        alias: 'Kid Phone',
        mode: JsonDeviceMode.off,
        retention: '24h',
        profileId: 'prof_default',
        modeUntil: DateTime.utc(2026, 6, 8, 21, 0, 0),
      );
      d.lastHeartbeat = '2026-05-15T10:00:00Z';
      expect(d.toJson()['mode_until'], '2026-06-08T21:00:00.000Z');
    });

    test('non-UTC mode_until is serialised as UTC', () {
      // A local-zone instant must still go out as Z-suffixed UTC.
      final d = JsonDevice(
        deviceTag: 'tag1',
        alias: 'Kid Phone',
        mode: JsonDeviceMode.off,
        retention: '24h',
        profileId: 'prof_default',
        modeUntil: DateTime.utc(2026, 6, 8, 21, 0, 0).toLocal(),
      );
      d.lastHeartbeat = '2026-05-15T10:00:00Z';
      expect(d.toJson()['mode_until'], endsWith('Z'));
      expect(DateTime.parse(d.toJson()['mode_until'] as String).toUtc(),
          DateTime.utc(2026, 6, 8, 21, 0, 0));
    });
  });

  group('JsonDevicePayload.forUpdateMode mode_until', () {
    test('omits mode_until when none is supplied (indefinite, as before)', () {
      final p = JsonDevicePayload.forUpdateMode(
        deviceTag: 'tag1',
        mode: JsonDeviceMode.off,
      );
      final out = p.toJson();
      expect(out['mode'], 'off');
      expect(out.containsKey('mode_until'), isFalse);
    });

    test('emits mode_until when supplied', () {
      final p = JsonDevicePayload.forUpdateMode(
        deviceTag: 'tag1',
        mode: JsonDeviceMode.blocked,
        modeUntil: DateTime.utc(2026, 6, 8, 21, 0, 0),
      );
      final out = p.toJson();
      expect(out['mode'], 'blocked');
      expect(out['mode_until'], '2026-06-08T21:00:00.000Z');
    });

    test('other payload factories never carry mode_until', () {
      expect(
          JsonDevicePayload.forUpdateProfile(
                  deviceTag: 'tag1', profileId: 'p')
              .toJson()
              .containsKey('mode_until'),
          isFalse);
      expect(
          JsonDevicePayload.forUpdateAlias(deviceTag: 'tag1', alias: 'x')
              .toJson()
              .containsKey('mode_until'),
          isFalse);
    });
  });
}
