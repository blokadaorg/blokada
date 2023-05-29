import 'dart:async';

import '../util/di.dart';
import '../util/trace.dart';

abstract class TimerService {
  void set(String name, DateTime when);
  unset(String name);
  addHandler(String name, Function(Trace) handler);
}

class DefaultTimer with TimerService, TraceOrigin, Dependable {
  final Map<String, Timer> _timers = {};
  final Map<String, Function(Trace)> _handlers = {};

  @override
  attach() {
    depend<TimerService>(this);
  }

  @override
  void set(String name, DateTime when) {
    // TODO: timezones
    // TODO: timestmap in the past but not zero - refresh immediatelly? or ignore?
    // TODO: timer persist and fire after app restarted
    if (!_handlers.containsKey(name)) {
      throw Exception("No handler for timer $name");
    }

    unset(name);
    _timers[name] = Timer(when.difference(DateTime.now()), () async {
      await traceAs(name, (trace) async {
        await _handlers[name]?.call(trace);
      });
      // TODO: remove handler?
    });
  }

  @override
  unset(String name) {
    _timers[name]?.cancel();
    _timers.remove(name);
  }

  @override
  addHandler(String name, Function(Trace) handler) {
    _handlers[name] = handler;
  }
}

// A Timer used in tests that allows for manual trigger of handlers.
class TestingTimer with TimerService, TraceOrigin, Dependable {
  final Map<String, Function(Trace)> _handlers = {};

  @override
  attach() {
    depend<TimerService>(this);
  }

  @override
  void set(String name, DateTime when) {}

  @override
  unset(String name) {}

  @override
  addHandler(String name, Function(Trace) handler) {
    _handlers[name] = handler;
  }

  trigger(String name) async {
    await traceAs(name, (trace) async {
      await _handlers[name]?.call(trace);
    });
  }
}
