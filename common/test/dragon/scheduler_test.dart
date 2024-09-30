import 'package:common/dragon/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<SchedulerTimer>(),
])
import 'scheduler_test.mocks.dart';

void main() {
  group("Scheduler", () {
    test("basic", () async {
      await withTrace((m) async {
        final timer = MockSchedulerTimer();
        when(timer.callback = captureAny).thenReturn(null);

        final subject = Scheduler(timer: timer);

        final every2s = Job(
          "every2s",
          m,
          every: const Duration(seconds: 2),
          callback: (m) async => true,
        );

        final every3s = Job(
          "every3s",
          m,
          every: const Duration(seconds: 3),
          callback: (m) async => true,
        );

        final now = DateTime(0);
        when(timer.now()).thenReturn(now);
        subject.addOrUpdate(every2s);
        subject.addOrUpdate(every3s);
        verify(timer.setTimer(const Duration(seconds: 2))).called(1);

        // 2 seconds passed, should reschedule next timer
        when(timer.now()).thenReturn(now.add(const Duration(seconds: 2)));
        final timerCallback = verify(timer.callback = captureAny).captured;
        timerCallback.last();

        verify(timer.setTimer(const Duration(seconds: 3 - 2))).called(1);
      });
    });

    test("conditions", () async {
      await withTrace((m) async {
        final timer = MockSchedulerTimer();
        when(timer.callback = captureAny).thenReturn(null);
        when(timer.jobFail()).thenThrow(Exception("Should not exec job"));

        final subject = Scheduler(timer: timer);

        bool shouldCall = false;
        int called = 0;
        final inForeground = Job(
          "inForeground",
          m,
          every: const Duration(seconds: 1),
          when: [Condition(Event.appForeground, value: "1")],
          callback: (m) async {
            if (!shouldCall) throw Exception("Should not exec job");
            called++;
            return true;
          },
        );

        final now = DateTime(0);
        when(timer.now()).thenReturn(now);
        subject.addOrUpdate(inForeground);
        verify(timer.setTimer(const Duration(seconds: 1))).called(1);

        // 1 second passed, should reschedule but skip the job
        when(timer.now()).thenReturn(now.add(const Duration(seconds: 1)));
        final timerCallback = verify(timer.callback = captureAny).captured;
        timerCallback.last();

        verify(timer.setTimer(const Duration(seconds: 1))).called(1);

        // Event itself should trigger the callback too
        shouldCall = true;
        await subject.eventTriggered(m, Event.appForeground, value: "1");
        expect(called, 1);

        // more time passed, conditions ok, should exec job also
        when(timer.now()).thenReturn(now.add(const Duration(seconds: 2)));
        timerCallback.last();
        expect(called, 2);

        // another execution
        when(timer.now()).thenReturn(now.add(const Duration(seconds: 3)));
        timerCallback.last();
      });
    });
  });
}
