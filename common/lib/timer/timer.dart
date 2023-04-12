import 'dart:async';

import '../util/di.dart';

abstract class TimerService {
  void set(String name, DateTime when);
  unset(String name);
  addHandler(String name, Function handler);
}

class TimerImpl with TimerService {

  final Map<String, Timer> _timers = {};
  final Map<String, Function> _handlers = {};

  @override
  void set(String name, DateTime when) {
    // TODO: timezones
    // TODO: timestmap in the past but not zero - refresh immediatelly? or ignore?
    // TODO: timer persist and fire after app restarted
    if (!_handlers.containsKey(name)) {
      throw Exception("No handler for timer $name");
    }

    unset(name);
    _timers[name] = Timer(when.difference(DateTime.now()), () {
      _handlers[name]?.call();
      // TODO: remove handler?
    });
  }

  @override
  unset(String name) {
    _timers[name]?.cancel();
    _timers.remove(name);
  }

  @override
  addHandler(String name, Function handler) {
    _handlers[name] = handler;
  }
}

// A Timer used in tests that allows for manual trigger of handlers.
class TestingTimer with TimerService {
  final Map<String, Function> _handlers = {};

  @override
  void set(String name, DateTime when) {}

  @override
  unset(String name) {}

  @override
  addHandler(String name, Function handler) {
    _handlers[name] = handler;
  }

  trigger(String name) {
    _handlers[name]?.call();
  }
}

Future<void> init() async {
  di.registerSingleton<TimerService>(TimerImpl());
}
