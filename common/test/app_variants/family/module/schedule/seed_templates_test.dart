import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('seeded schedule shape', () {
    test(
        'produces School Mon-Fri 08:00-15:00 and Bedtime every day 21:00-07:00 '
        'with paused=false', () {
      final schedule = buildSeededSchedule(
        schoolProfileId: 'prof_school',
        bedtimeProfileId: 'prof_bedtime',
      );

      expect(schedule.paused, isFalse);
      expect(schedule.rules, hasLength(2));

      final school = schedule.rules[0];
      expect(school.profileId, 'prof_school');
      expect(school.weekdays, [1, 2, 3, 4, 5]);
      expect(school.windows, hasLength(1));
      expect(school.windows.first.startMinute, 8 * 60);
      expect(school.windows.first.endMinute, 15 * 60);

      final bedtime = schedule.rules[1];
      expect(bedtime.profileId, 'prof_bedtime');
      expect(bedtime.weekdays, [1, 2, 3, 4, 5, 6, 7]);
      expect(bedtime.windows.first.startMinute, 21 * 60);
      expect(bedtime.windows.first.endMinute, 7 * 60);
      expect(bedtime.windows.first.wrapsToNextDay, isTrue);
    });
  });
}
