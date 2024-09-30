import 'package:common/logger/logger.dart';
import 'package:common/timer/timer.dart';
import 'package:common/util/di.dart';

mixin Emitter on Logging {
  final Map<EmitterEvent, List<Function(Marker)>> _valueListeners = {};

  willAcceptOn(List<EmitterEvent> events) {
    _valueListeners.clear();
    _valueListeners.addEntries(events.map((it) => MapEntry(it, [])));
  }

  addOn(EmitterEvent on, Function(Marker) listener) {
    final listeners = _valueListeners[on];
    if (listeners == null) throw Exception("Unknown event");
    listeners.add(listener);
  }

  removeOn(EmitterEvent on, dynamic listener) {
    _valueListeners[on]?.remove(listener);
  }

  emit<T>(EmitterEvent<T> on, T value, Marker m) async {
    log(m).i("emit event: $on");

    final listeners = _valueListeners[on];
    if (listeners == null) throw Exception("Unknown event");
    for (final listener in listeners.toList()) {
      // Ignore any listener errors
      try {
        await listener(m);
      } catch (e, s) {
        log(m).e(msg: "listener threw error", err: e, stack: s);
      }
    }
  }
}

mixin ValueEmitter<T> on Logging {
  final List<Function(T, Marker)> _listeners = [];
  final executor = CallbackExecutor();
  late EmitterEvent<T> event;

  willAcceptOnValue(EmitterEvent<T> event) {
    this.event = event;
    _listeners.clear();
  }

  addOnValue(EmitterEvent<T> on, Function(T, Marker) listener) {
    if (on != event) throw Exception("Unknown event");
    _listeners.add(listener);
  }

  removeOnValue(EmitterEvent<T> on, dynamic listener) {
    _listeners.remove(listener);
  }

  emitValue(EmitterEvent<T> on, T value, Marker m) async {
    if (on != event) throw Exception("Unknown event");
    for (final listener in _listeners.toList()) {
      await executor.callListener(on, listener, value, m);
    }
  }
}

class EmitterEvent<T> {
  final String name;

  EmitterEvent(this.name);

  @override
  String toString() => name;
}

class CallbackExecutor with Logging {
  late final _timer = dep<TimerService>();
  final timeout = const Duration(seconds: 10);

  callListener<T>(EmitterEvent<T> on, Function(T, Marker) listener, T value,
      Marker m) async {
    // Ignore any listener errors
    // Don't wait for finish to not block other events
    final name = "on#$on#${listener.hashCode}";
    await log(m).trace(name, (m) async {
      _startTimeout(name);
      try {
        await listener(value, m);
        _stopTimeout(name);
      } catch (e) {
        _stopTimeout(name);
        rethrow;
      }
    });
  }

  _startTimeout<T>(String name) {
    _onTimer(name);
    _timer.set(name, DateTime.now().add(timeout));
  }

  _stopTimeout(String name) {
    _timer.unset(name);
  }

  _onTimer(String name) {
    try {
      _timer.addHandler(name, (_) async {
        // This will just show up in tracing
        throw Exception("Event callback '$name' is too slow");
      });
    } catch (e) {}
  }
}
