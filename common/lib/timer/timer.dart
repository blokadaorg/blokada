import 'dart:async';

import 'package:common/core/core.dart';

abstract class TimerService {
  void set(String name, DateTime when);
  unset(String name);
  addHandler(String name, Function(Marker) handler);
}

class DefaultTimer with Logging, Actor implements TimerService {
  final Map<String, Timer> _timers = {};
  final Map<String, Function(Marker)> _handlers = {};

  @override
  onRegister(Act act) {
    this.act = act;
    DI.register<TimerService>(this);
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
      await log(Markers.timer).trace(name, (m) async {
        await _handlers[name]?.call(m);
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
  addHandler(String name, Function(Marker) handler) {
    _handlers[name] = handler;
  }
}

// A Timer used in tests that allows for manual trigger of handlers.
class TestingTimer with Logging, Actor implements TimerService {
  final Map<String, Function(Marker)> _handlers = {};

  @override
  onRegister(Act act) {
    DI.register<TimerService>(this);
  }

  @override
  void set(String name, DateTime when) {}

  @override
  unset(String name) {}

  @override
  addHandler(String name, Function(Marker) handler) {
    _handlers[name] = handler;
  }

  trigger(String name) async {
    await log(Markers.timer).trace(name, (m) async {
      await _handlers[name]?.call(m);
    });
  }
}
