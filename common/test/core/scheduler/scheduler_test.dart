import 'package:common/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
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
        final timerCallback = verify(timer.callback = captureAny).captured;

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
        verify(timer.setTimer(const Duration(seconds: 2))).called(1);
        await subject.addOrUpdate(every3s);
        verify(timer.setTimer(const Duration(seconds: 2))).called(1);

        // 2 seconds passed, should reschedule next timer
        when(timer.now()).thenReturn(now.add(const Duration(seconds: 2)));
        await timerCallback.last();

        verify(timer.setTimer(const Duration(seconds: 1))).called(1);
      });
    });

    test("conditions", () async {
      await withTrace((m) async {
        final timer = MockSchedulerTimer();
        when(timer.callback = captureAny).thenReturn(null);
        when(timer.jobFail()).thenThrow(Exception("Should not exec job"));

        final subject = Scheduler(timer: timer);
        final timerCallback = verify(timer.callback = captureAny).captured;

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
        final now = DateTime(0);
        when(timer.now()).thenReturn(now);
        await subject.addOrUpdate(inForeground);
        verify(timer.setTimer(null)).called(1);

        // 1 second passed, should not reschedule but skip the job
        when(timer.now()).thenReturn(now.add(const Duration(seconds: 1)));
        timerCallback.last();

        verify(timer.setTimer(null)).called(1);

        // Event itself should trigger the callback too and set the timer
        shouldCall = true;
        await subject.eventTriggered(m, Event.appForeground, value: "1");
        //expect(called, 1); // Now its async
        verify(timer.setTimer(const Duration(seconds: 0))).called(1);

        // more time passed, conditions ok, should exec job also
        when(timer.now()).thenReturn(now.add(const Duration(seconds: 2)));
        timerCallback.last();
        //expect(called, 2);

        // another execution
        when(timer.now()).thenReturn(now.add(const Duration(seconds: 3)));
        timerCallback.last();
      });
    });

    test("backgroundScheduling", () async {
      await withTrace((m) async {
        final timer = MockSchedulerTimer();
        when(timer.callback = captureAny).thenReturn(null);
        when(timer.jobFail()).thenThrow(Exception("Should not exec job"));

        final subject = Scheduler(timer: timer);

        bool shouldCall = false;
        int job1Called = 0;

        final inForeground = Job(
          "inForeground",
          m,
          every: const Duration(seconds: 1),
          when: [Condition(Event.appForeground, value: "1")],
          callback: (m) async {
            if (!shouldCall) throw Exception("Should not exec job");
            job1Called++;
            return true;
          },
        );

        int job2Called = 0;
        final alsoInBackground = Job(
          "alsoInBackgound",
          m,
          every: const Duration(seconds: 4),
          callback: (m) async {
            if (!shouldCall) throw Exception("Should not exec job");
            job2Called++;
            return true;
          },
        );

        // If there are more jobs, timer of the first matching job would be called
        // Meaning fg job should be ignored when in bg

        final now = DateTime(0);
        when(timer.now()).thenReturn(now);
        await subject.eventTriggered(m, Event.appForeground, value: "1");
        await subject.addOrUpdate(inForeground);
        verify(timer.setTimer(const Duration(seconds: 1))).called(1);
        await subject.addOrUpdate(alsoInBackground);
        verify(timer.setTimer(const Duration(seconds: 1))).called(1);

        // We go to bg now, the first job should be skipped but second one no
        await subject.eventTriggered(m, Event.appForeground, value: "0");
        when(timer.now()).thenReturn(now.add(const Duration(seconds: 1)));
        verify(timer.setTimer(const Duration(seconds: 4))).called(1);

        // We go to fg now after 1 sec, should reschedule the first job.
        when(timer.now()).thenReturn(now.add(const Duration(seconds: 2)));
        await subject.eventTriggered(m, Event.appForeground, value: "1");
        verify(timer.setTimer(const Duration(seconds: 0))).called(1);

        expect(job1Called, 0);
        expect(job2Called, 0);
      });
    });
  });
}
