import 'dart:async';

import 'package:dartx/dartx.dart';

class Job {
  final String name;
  final DateTime? before;
  final Duration? every;
  final List<Condition> when;
  final bool Function()? skip;
  final Future<bool> Function() callback;

  late DateTime next;

  Job(
    this.name, {
    this.before,
    this.every,
    this.when = const [],
    this.skip,
    required this.callback,
  });

  @override
  bool operator ==(Object other) {
    return other is Job && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}

enum Event {
  appForeground;
}

class Condition {
  final Event event;
  final String? value;

  Condition(this.event, {this.value});

  @override
  bool operator ==(Object other) {
    return other is Condition && other.event == event;
  }

  @override
  int get hashCode => event.hashCode;
}

class JobOrder implements Comparable<JobOrder> {
  final DateTime when;
  final Job job;

  JobOrder(this.when, this.job);

  @override
  bool operator ==(Object other) {
    return other is JobOrder && other.job == job;
  }

  @override
  int get hashCode => job.hashCode;

  @override
  int compareTo(JobOrder other) {
    return when.compareTo(other.when);
  }
}

class SchedulerException implements Exception {
  final bool canRetry;
  final Object cause;

  SchedulerException(this.cause, {this.canRetry = false});

  @override
  String toString() {
    return "SchedulerException: $cause";
  }
}

class Scheduler {
  final List<Condition> _conditions = [];
  final List<Job> _jobs = [];
  final List<JobOrder> _next = [];
  final Map<Job, int> _failures = {};

  final SchedulerTimer timer;

  Scheduler({required this.timer}) {
    timer.callback = _timerCallback;
  }

  addOrUpdate(Job job, {bool immediate = false}) {
    _jobs.removeWhere((j) => j == job);
    _jobs.add(job);
    _next.removeWhere((o) => o.job == o.job);
    _reschedule(job, immediate: immediate);
    _setTimer();
  }

  // think about if its necessary, the return bool from callback may be enough
  stop(String jobName) {
    _jobs.removeWhere((j) => j.name == jobName);
    _next.removeWhere((o) => o.job.name == jobName);
    _setTimer();
  }

  eventTriggered(Event event, {String? value}) async {
    print("Event triggered: $event, now: $value");

    final c = Condition(event, value: value);
    _conditions.remove(c);
    _conditions.add(c);

    for (final job in _jobs.toList()) {
      final when = job.when.indexOf(c);
      if (when == -1) continue;
      if (!_checkAllConditions(job)) continue;
      if (!(job.skip?.call() ?? false)) {
        await _invoke(job); // should await?
      }
    }
    _setTimer();
  }

  _checkAllConditions(Job job) {
    for (final when in job.when) {
      if (when.value == null) continue;
      final c = _conditions.indexOf(when);
      if (c == -1) return false;
      if (when.value != _conditions.elementAt(c).value) return false;
    }
    return true;
  }

  _invoke(Job job) async {
    print("Running job ${job.name} at ${timer.now()}");
    try {
      //_jobs.remove(job);
      final reschedule = await job.callback();
      _failures.remove(job);
      if (reschedule) _reschedule(job);
    } on SchedulerException catch (e) {
      final failures = _failures[job] ?? 0;
      if (e.canRetry && failures < 5) {
        print("rescheduling failed job");
        _failures[job] = failures + 1;
        _reschedule(job, retry: true);
      } else {
        print("Job ${job.name} failed too many times, wont retry: $e");
        timer.jobFail();
      }
    } catch (e) {
      print("Job ${job.name} failed: $e");
      timer.jobFail();
    }
  }

  _reschedule(Job job, {bool immediate = false, bool retry = false}) {
    final now = timer.now();
    DateTime? next;

    if (job.every != null) {
      next = now.add(job.every!);
      if (immediate) next = now;
    }

    if (job.before != null && (next == null || job.before!.isBefore(next))) {
      next = job.before!;
    }

    if (retry) {
      final retryTime = now.add(const Duration(seconds: 5));
      if (next == null || retryTime.isBefore(next)) {
        next = retryTime;
      }
    }

    print("Rescheduling job ${job.name}, next: $next (now: $now)");
    if (next == null) return;

    final order = JobOrder(next, job);
    _next.remove(order); // remove old one if exists (should be only one)
    _next.add(order);
    _next.sort();
  }

  _setTimer() {
    final upcoming = _next.firstOrNull;
    if (upcoming == null) {
      print("Next job: none, nothing in queue");
      timer.setTimer(null);
      return;
    }

    final now = timer.now();
    final when = upcoming.when.difference(now);
    print("Next job ${upcoming.job.name} at ${upcoming.when} (in $when)");
    try {
      timer.setTimer(when);
    } catch (e) {
      print("Failed to set timer: $e");
    }
  }

  _timerCallback() async {
    final now = timer.now();
    final jobs =
        _next.takeWhile((j) => !j.when.isAfter(now)).toList().distinct();
    _next.removeWhere((j) => !j.when.isAfter(now));

    for (final job in jobs) {
      if (_checkAllConditions(job.job)) {
        if (!(job.job.skip?.call() ?? false)) {
          await _invoke(job.job); // should await?
          continue;
        }
      }
      _reschedule(job.job);
    }

    _setTimer();
  }
}

class SchedulerTimer {
  Timer? _timer;
  late Function() callback;
  late Function() jobFail;

  SchedulerTimer() {
    jobFail = () {
      print("job failed");
    };
  }

  setTimer(Duration? inWhen) {
    _timer?.cancel();
    if (inWhen != null) _timer = Timer(inWhen, callback);
  }

  DateTime now() {
    return DateTime.now();
  }
}
