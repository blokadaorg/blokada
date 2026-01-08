part of 'core.dart';

class Job {
  final String name;
  final DateTime? before;
  final Duration? every;
  final List<Condition> when;
  final bool Function()? skip;
  final Future<bool> Function(Marker) callback;
  final Marker marker;

  late DateTime next;

  Job(
    this.name,
    this.marker, {
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

class Conditions {
  // App must be in foreground to execute this job
  static final foreground = Condition(Event.appForeground, value: "1");
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

class Scheduler with Logging {
  final List<Condition> _conditions = [];
  final List<Job> _jobs = [];
  final List<JobOrder> _next = [];
  final Map<Job, int> _failures = {};

  final SchedulerTimer timer;

  Scheduler({required this.timer}) {
    timer.callback = _timerCallback;
  }

  addOrUpdate(Job job, {bool immediate = false}) async {
    await log(job.marker).trace("addOrUpdate", (m) async {
      log(m).pair("job", job.name);
      log(m).pair("immediate", immediate);

      _jobs.removeWhere((j) => j == job);
      _jobs.add(job);
      _next.removeWhere((o) => o.job == job);
      _reschedule(job.marker, job, immediate: immediate);
      _setTimer(m);
    });
  }

  // think about if its necessary, the return bool from callback may be enough
  stop(Marker m, String jobName) async {
    await log(m).trace("stop", (m) async {
      log(m).pair("job", jobName);

      _jobs.removeWhere((j) => j.name == jobName);
      _next.removeWhere((o) => o.job.name == jobName);
      _setTimer(m);
    });
  }

  eventTriggered(Marker m, Event event, {String? value}) async {
    await log(m).trace(event.name, (m) async {
      log(m).t("Event triggered: $event, now: $value");

      final c = Condition(event, value: value);
      _conditions.remove(c);
      _conditions.add(c);

      for (final job in _jobs.toList()) {
        final when = job.when.indexOf(c);
        log(m).t("Analyze job: ${job.name}, when: $when");
        if (when == -1) continue;
        _next.removeWhere((o) => o.job == job);
        _reschedule(m, job, immediate: true);
      }
      _setTimer(m);
    });
  }

  // Manual ping of a job execution from background task
  pingFromBackground(Marker m) async {
    await log(m).trace("pingFromBackground", (m) async {
      _setTimer(m);
    });
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
    await log(job.marker).trace("job::${job.name}", (m) async {
      try {
        //_jobs.remove(job);
        final reschedule = await job.callback(m);
        _failures.remove(job);
        if (reschedule) _reschedule(m, job);
      } on SchedulerException catch (e, s) {
        final failures = _failures[job] ?? 0;
        if (e.canRetry && failures < 5) {
          log(m).w("rescheduling failed job");
          _failures[job] = failures + 1;
          _reschedule(m, job, retry: true);
        } else {
          log(m).e(
              msg: "Job ${job.name} failed too many times, wont retry",
              err: e,
              stack: s);
          timer.jobFail();
        }
      } catch (e, s) {
        log(m).e(msg: "Job ${job.name} failed", err: e, stack: s);
        timer.jobFail();
      }
    });
  }

  _reschedule(Marker m, Job job, {bool immediate = false, bool retry = false}) {
    log(m).t("Reschedule ${job.name}");

    final now = timer.now();
    DateTime? next;

    // If conditions are not met for this job, just ignore it until next check
    if (_checkAllConditions(job)) {
      if (job.every != null) {
        next = now.add(job.every!);
        if (immediate) {
          log(m).i("Job ${job.name} is immediate");
          next = now;
        }
      }

      if (job.before != null && (next == null || job.before!.isBefore(next))) {
        next = job.before!;
      }
    } else {
      log(m).i("Conditions not met for job ${job.name}, ignoring");
    }

    if (retry) {
      final retryTime = now.add(const Duration(seconds: 5));
      if (next == null || retryTime.isBefore(next)) {
        next = retryTime;
      }
    }

    if (next == null) {
      log(m).i("Job ${job.name} is skipped for now");
      return;
    }

    _getWhen(m, job, next);

    final order = JobOrder(next, job);
    _next.remove(order); // remove old one if exists (should be only one)
    _next.add(order);
    _next.sort();
  }

  _setTimer(Marker m) {
    final upcoming = _next.firstOrNull;
    if (upcoming == null) {
      timer.setTimer(null);
      return;
    }

    final when = _getWhen(m, upcoming.job, upcoming.when, prefix: "Next");

    try {
      timer.setTimer(when);
    } catch (e, s) {
      log(m).e(msg: "Failed to set timer", err: e, stack: s);
    }
  }

  Duration _getWhen(Marker m, Job job, DateTime time, {prefix = "Job"}) {
    final now = timer.now();
    final when = time.difference(now);
    if (time.isBefore(now) || when.inSeconds < 1) {
      log(m).i("$prefix ${job.name}, now");
    } else {
      log(m).i("$prefix ${job.name}, at $time (in $when)");
    }
    return when;
  }

  _timerCallback() async {
    await log(Markers.timer).trace("scheduler", (m) async {
      final now = timer.now();
      final jobs =
          _next.takeWhile((j) => !j.when.isAfter(now)).toList().distinct();
      _next.removeWhere((j) => !j.when.isAfter(now));

      for (final job in jobs) {
        if (_checkAllConditions(job.job)) {
          if (!(job.job.skip?.call() ?? false)) {
            log(m).i("Invoking job ${job.job.name}");
            await _invoke(job.job);
            continue;
          }
        }
        _reschedule(job.job.marker, job.job);
      }

      _setTimer(m);
    });
  }
}

class SchedulerTimer with Logging {
  Timer? _timer;
  late Function() callback;
  late Function() jobFail;

  SchedulerTimer() {
    jobFail = () {
      log(Markers.timer).i("job failed");
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
