part of 'schedule.dart';

/// Pure helper. Produces the two-rule seeded schedule used on first device
/// setup. The caller (DeviceActor.reload) is responsible for creating the
/// two profiles ("School", "Bedtime") via ProfileActor.addProfile beforehand
/// and passing their ids in.
///
/// Decisions of record (coordinator plan §"Spec questions resolved"):
/// - School: Mon–Fri 08:00–15:00 (start_minute 480, end_minute 900)
/// - Bedtime: every day 21:00–07:00 (start_minute 1260, end_minute 420 →
///   wrapsToNextDay = true)
/// - paused=false. The Default is the device's existing top-level
///   `profile_id` — not part of this seed.
ScheduleModel buildSeededSchedule({
  required String schoolProfileId,
  required String bedtimeProfileId,
}) {
  return ScheduleModel(
    paused: false,
    rules: [
      RuleModel(
        profileId: schoolProfileId,
        weekdays: const [1, 2, 3, 4, 5],
        windows: const [
          TimeWindowModel(startMinute: 8 * 60, endMinute: 15 * 60),
        ],
      ),
      RuleModel(
        profileId: bedtimeProfileId,
        weekdays: const [1, 2, 3, 4, 5, 6, 7],
        windows: const [
          TimeWindowModel(startMinute: 21 * 60, endMinute: 7 * 60),
        ],
      ),
    ],
  );
}
