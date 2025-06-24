part of 'core.dart';

mixin Emitter on Logging {
  final Map<EmitterEvent, List<Function(Marker)>> _valueListeners = {};
  final Map<EmitterEvent, dynamic> _latestValue = {};

  willAcceptOn(List<EmitterEvent> events) {
    _valueListeners.clear();
    _valueListeners.addEntries(events.map((it) => MapEntry(it, [])));
  }

  addOn<T>(EmitterEvent<T> on, Function(Marker) listener) {
    final listeners = _valueListeners[on];
    if (listeners == null) throw Exception("Unknown event");
    listeners.add(listener);

    final latest = _latestValue[on];
    if (latest != null) {
      log(Markers.valueChange).trace("emitter", (m) async {
        log(m).i("Instant emit for $on");
        await listener(m);
      });
    }
  }

  removeOn(EmitterEvent on, dynamic listener) {
    _valueListeners[on]?.remove(listener);
  }

  emit<T>(EmitterEvent<T> on, T value, Marker m) async {
    log(m).i("emit event: $on");

    final listeners = _valueListeners[on];
    if (listeners == null) throw Exception("Unknown event");
    _latestValue[on] = value;
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
  final Map<EmitterEvent<T>, List<Function(T, Marker)>> _eventListeners = {};
  final executor = CallbackExecutor();

  willAcceptOnValue(EmitterEvent<T> event, [List<EmitterEvent<T>>? additionalEvents]) {
    _eventListeners.clear();
    final events = [event, ...(additionalEvents ?? [])];
    _eventListeners.addEntries(events.map((it) => MapEntry(it, [])));
  }

  addOnValue(EmitterEvent<T> on, Function(T, Marker) listener) {
    final listeners = _eventListeners[on];
    if (listeners == null) throw Exception("Unknown event");
    listeners.add(listener);
  }

  removeOnValue(EmitterEvent<T> on, dynamic listener) {
    _eventListeners[on]?.remove(listener);
  }

  emitValue(EmitterEvent<T> on, T value, Marker m) async {
    final listeners = _eventListeners[on];
    if (listeners == null) throw Exception("Unknown event");
    for (final listener in listeners.toList()) {
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
  final timeout = const Duration(seconds: 10);

  callListener<T>(EmitterEvent<T> on, Function(T, Marker) listener, T value,
      Marker m) async {
    // Ignore any listener errors
    // Don't wait for finish to not block other events
    final name = "on#$on#${listener.hashCode}";
    await log(m).trace(name, (m) async {
      try {
        await listener(value, m);
      } catch (e) {
        rethrow;
      }
    });
  }
}
