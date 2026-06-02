import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/app_variants/family/widget/home/device/home_device.dart';
import 'package:flutter_test/flutter_test.dart';

JsonProfile _profile(String id, String name) => JsonProfile(
      profileId: id,
      alias: '$name (child)',
      lists: const [],
      safeSearch: false,
    );

JsonDevice _device({
  required JsonProfile profile,
  JsonDeviceMode mode = JsonDeviceMode.on,
  DateTime? modeUntil,
  ScheduleModel? schedule,
}) =>
    JsonDevice(
      deviceTag: 'device-1',
      alias: 'Kid phone',
      mode: mode,
      modeUntil: modeUntil,
      retention: '24h',
      profileId: profile.profileId,
      schedule: schedule,
    );

void main() {
  final fallback = _profile('prof_default', 'Children');
  final bedtime = _profile('prof_bedtime', 'Bedtime');
  final profiles = [fallback, bedtime];

  // Wall-clock the assertions don't depend on: a fixed instant fed to the
  // pure resolver. Whether a rule "fires" is controlled by the windows below,
  // not by [now], so these never flake on the real clock.
  final now = DateTime(2026, 6, 3, 21, 30);

  // A rule that fires at every minute (all weekdays; two windows that together
  // cover all 1440 minutes, the wrap window picking up the minute the first
  // misses).
  ScheduleModel alwaysFiring() => ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: 'prof_bedtime',
            weekdays: const [1, 2, 3, 4, 5, 6, 7],
            windows: const [
              TimeWindowModel(startMinute: 0, endMinute: 1439),
              TimeWindowModel(startMinute: 1439, endMinute: 1),
            ],
          ),
        ],
      );

  test('a firing rule → the rule profile', () {
    final result = activeProfileForCard(alwaysFiring(), fallback, profiles, now);
    expect(result.profileId, 'prof_bedtime');
  });

  test('paused schedule → the default', () {
    final paused = ScheduleModel(
      paused: true,
      rules: [
        RuleModel(
          profileId: 'prof_bedtime',
          weekdays: const [1, 2, 3, 4, 5, 6, 7],
          windows: const [TimeWindowModel(startMinute: 0, endMinute: 1439)],
        ),
      ],
    );
    final result = activeProfileForCard(paused, fallback, profiles, now);
    expect(result.profileId, 'prof_default');
  });

  test('rule outside its window → the default', () {
    // Window covers only minute 0; now (21:30 = minute 1290) is outside it.
    final offWindow = ScheduleModel(
      paused: false,
      rules: [
        RuleModel(
          profileId: 'prof_bedtime',
          weekdays: const [1, 2, 3, 4, 5, 6, 7],
          windows: const [TimeWindowModel(startMinute: 0, endMinute: 1)],
        ),
      ],
    );
    final result = activeProfileForCard(offWindow, fallback, profiles, now);
    expect(result.profileId, 'prof_default');
  });

  test('no schedule → the default', () {
    final result = activeProfileForCard(null, fallback, profiles, now);
    expect(result.profileId, 'prof_default');
  });

  test('firing rule whose profile is missing from the list → the default', () {
    // The active rule points at prof_bedtime, but only the default is known.
    final result = activeProfileForCard(alwaysFiring(), fallback, [fallback], now);
    expect(result.profileId, 'prof_default');
  });

  // A firing block rule (no profile) covering every minute.
  ScheduleModel alwaysBlocking() => ScheduleModel(
        paused: false,
        rules: [
          RuleModel(
            profileId: '',
            weekdays: const [1, 2, 3, 4, 5, 6, 7],
            windows: const [
              TimeWindowModel(startMinute: 0, endMinute: 1439),
              TimeWindowModel(startMinute: 1439, endMinute: 1),
            ],
            action: 'block',
          ),
        ],
      );

  test('label: a firing block rule → the "No internet" key, not the default', () {
    // Block rules carry no profile, so the card must not fall back to naming
    // the default profile (which would hide that all internet is blocked).
    final label = activeCardLabelKey(
      _device(profile: fallback, schedule: alwaysBlocking()),
      fallback,
      profiles,
      now,
    );
    expect(label, 'family schedule rule block title');
  });

  test('label: a firing filter rule → the active profile alias', () {
    final label = activeCardLabelKey(
      _device(profile: fallback, schedule: alwaysFiring()),
      fallback,
      profiles,
      now,
    );
    expect(label, bedtime.displayAlias);
  });

  test('label: no rule firing → the default profile alias', () {
    final label = activeCardLabelKey(
      _device(profile: fallback),
      fallback,
      profiles,
      now,
    );
    expect(label, fallback.displayAlias);
  });

  test('label: active manual block override → the "No internet" key', () {
    final label = activeCardLabelKey(
      _device(
        profile: fallback,
        mode: JsonDeviceMode.blocked,
        modeUntil: now.add(const Duration(hours: 1)),
        schedule: alwaysFiring(),
      ),
      fallback,
      profiles,
      now,
    );
    expect(label, 'family schedule rule block title');
  });

  test('label: active manual pause override → internet open key', () {
    final label = activeCardLabelKey(
      _device(
        profile: fallback,
        mode: JsonDeviceMode.off,
        modeUntil: now.add(const Duration(hours: 1)),
        schedule: alwaysFiring(),
      ),
      fallback,
      profiles,
      now,
    );
    expect(label, 'family device now status allow');
  });

  test('label: expired manual override falls through to the schedule', () {
    final label = activeCardLabelKey(
      _device(
        profile: fallback,
        mode: JsonDeviceMode.blocked,
        modeUntil: now.subtract(const Duration(minutes: 1)),
        schedule: alwaysFiring(),
      ),
      fallback,
      profiles,
      now,
    );
    expect(label, bedtime.displayAlias);
  });
}
