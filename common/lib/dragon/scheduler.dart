class Job {
  final String name;
  final DateTime? before;
  final Duration? every;
  final List<Condition> when;
  final bool Function()? skip;
  final bool Function() callback;

  late DateTime next;

  Job(
    this.name, {
    this.before,
    this.every,
    this.when = const [],
    this.skip,
    required this.callback,
  });
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

class Scheduler {
  final List<Condition> _conditions = [];
  final List<Job> _jobs = [];

  addOrUpdate(Job job) {
    _jobs.removeWhere((j) => j.name == job.name);
    _reschedule(job);
  }

  eventTriggered(Event event, {String? value}) {
    final c = Condition(event, value: value);
    _conditions.remove(c);
    _conditions.add(c);

    for (final job in _jobs) {
      final when = job.when.indexOf(c);
      if (when == -1) continue;
      if (!_checkAllConditions(job)) continue;
      if (!(job.skip?.call() ?? false)) {
        try {
          _jobs.remove(job);
          final reschedule = job.callback();
          if (reschedule) _reschedule(job);
        } catch (e) {
          print("Job ${job.name} failed: $e");
        }
      }
    }
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

  _reschedule(Job job) {
    DateTime? next;

    if (job.every != null) {
      next = DateTime.now().add(job.every!);
    }

    if (job.before != null && (next == null || job.before!.isBefore(next))) {
      next = job.before!;
    }

    if (next == null) return;
  }
}
