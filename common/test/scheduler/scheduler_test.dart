import 'package:common/scheduler/scheduler.dart';
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
        await subject.addOrUpdate(every2s);
        await subject.addOrUpdate(every3s);
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

        // When adding a job but conditions not met, clear timer
        // If there were more jobs, timer of the first matching job would be called
        final now = DateTime(0);
        when(timer.now()).thenReturn(now);
        await subject.addOrUpdate(inForeground);
        verify(timer.setTimer(null)).called(1);

        // 1 second passed, should not reschedule but skip the job
        when(timer.now()).thenReturn(now.add(const Duration(seconds: 1)));
        final timerCallback = verify(timer.callback = captureAny).captured;
        timerCallback.last();

        verify(timer.setTimer(null)).called(1);

        // Event itself should trigger the callback too and set the timer
        shouldCall = true;
        await subject.eventTriggered(m, Event.appForeground, value: "1");
        expect(called, 1);
        verify(timer.setTimer(const Duration(seconds: 1))).called(1);

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
