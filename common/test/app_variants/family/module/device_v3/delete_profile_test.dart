import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

JsonProfile _profile(String id) => JsonProfile(
      profileId: id,
      alias: 'Custom ()',
      lists: const [],
      safeSearch: false,
    );

JsonDevice _device({
  required String tag,
  required String profileId,
  ScheduleModel? schedule,
}) =>
    JsonDevice(
      deviceTag: tag,
      alias: 'dev_$tag',
      mode: JsonDeviceMode.on,
      retention: '24h',
      profileId: profileId,
      schedule: schedule,
    );

ScheduleModel _scheduleTargeting(String profileId) => ScheduleModel(
      paused: false,
      rules: [
        RuleModel(
          profileId: profileId,
          weekdays: const [1, 2, 3, 4, 5],
          windows: const [TimeWindowModel(startMinute: 480, endMinute: 900)],
        ),
      ],
    );

void main() {
  group('DeviceActor.checkProfileDeletable', () {
    test('returns null when no device references the profile', () {
      final result = DeviceActor.checkProfileDeletable(
        [
          _device(tag: 'd1', profileId: 'prof_other'),
          _device(tag: 'd2', profileId: 'prof_other'),
        ],
        _profile('prof_target'),
      );
      expect(result, isNull);
    });

    test('blocks with deviceDefault when a device\'s default points at it',
        () {
      final result = DeviceActor.checkProfileDeletable(
        [
          _device(tag: 'd1', profileId: 'prof_target'),
        ],
        _profile('prof_target'),
      );
      expect(result, isNotNull);
      expect(result!.reason, ProfileInUseReason.deviceDefault);
      expect(result.affectedDevices.map((d) => d.deviceTag), ['d1']);
    });

    test('blocks with ruleTarget when only a schedule rule references it',
        () {
      final result = DeviceActor.checkProfileDeletable(
        [
          _device(
            tag: 'd1',
            profileId: 'prof_other',
            schedule: _scheduleTargeting('prof_target'),
          ),
        ],
        _profile('prof_target'),
      );
      expect(result, isNotNull);
      expect(result!.reason, ProfileInUseReason.ruleTarget);
      expect(result.affectedDevices.map((d) => d.deviceTag), ['d1']);
    });

    test(
        'deviceDefault takes precedence when a device both defaults to AND '
        'rule-targets the profile', () {
      final result = DeviceActor.checkProfileDeletable(
        [
          _device(
            tag: 'd1',
            profileId: 'prof_target',
            schedule: _scheduleTargeting('prof_target'),
          ),
        ],
        _profile('prof_target'),
      );
      expect(result, isNotNull);
      expect(result!.reason, ProfileInUseReason.deviceDefault);
      // The deviceDefault branch wins and ONLY carries the devices that
      // match by default (not the rule-target overlap).
      expect(result.affectedDevices.map((d) => d.deviceTag), ['d1']);
    });

    test(
        'rule on one device blocks deletion even when other devices are '
        'clean (profiles are account-global)', () {
      final result = DeviceActor.checkProfileDeletable(
        [
          _device(tag: 'd1', profileId: 'prof_other'),
          _device(
            tag: 'd2',
            profileId: 'prof_other',
            schedule: _scheduleTargeting('prof_target'),
          ),
          _device(tag: 'd3', profileId: 'prof_other'),
        ],
        _profile('prof_target'),
      );
      expect(result, isNotNull);
      expect(result!.reason, ProfileInUseReason.ruleTarget);
      // Only the device whose schedule actually references the profile
      // is named, not every device in the account.
      expect(result.affectedDevices.map((d) => d.deviceTag), ['d2']);
    });

    test('schedule without rules does not falsely block', () {
      final result = DeviceActor.checkProfileDeletable(
        [
          _device(
            tag: 'd1',
            profileId: 'prof_other',
            schedule:
                const ScheduleModel(paused: false, rules: <RuleModel>[]),
          ),
        ],
        _profile('prof_target'),
      );
      expect(result, isNull);
    });
  });
}
