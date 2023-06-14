import 'trace.dart';

mixin Emitter {
  final Map<EmitterEvent, List<Function(Trace)>> _listeners = {};

  willAcceptOn(List<EmitterEvent> events) {
    _listeners.clear();
    _listeners.addEntries(events.map((it) => MapEntry(it, [])));
  }

  addOn(EmitterEvent on, Function(Trace) listener) {
    final listeners = _listeners[on];
    if (listeners == null) throw Exception("Unknown event");
    listeners.add(listener);
  }

  removeOn(EmitterEvent on, dynamic listener) {
    _listeners[on]?.remove(listener);
  }

  emit<T>(EmitterEvent<T> on, Trace trace, T value) async {
    final listeners = _listeners[on];
    if (listeners == null) throw Exception("Unknown event");
    for (final listener in listeners.toList()) {
      // Ignore any listener errors
      try {
        await listener(trace);
      } catch (e) {
        trace.addEvent("listener threw error: ${e.runtimeType}");
      }
    }
  }
}

mixin ValueEmitter<T> {
  final List<Function(Trace, T)> _listeners = [];
  late EmitterEvent<T> event;

  willAcceptOnValue(EmitterEvent<T> event) {
    this.event = event;
    _listeners.clear();
  }

  addOnValue(EmitterEvent<T> on, Function(Trace, T) listener) {
    if (on != event) throw Exception("Unknown event");
    _listeners.add(listener);
  }

  removeOnValue(EmitterEvent<T> on, dynamic listener) {
    _listeners.remove(listener);
  }

  emitValue(EmitterEvent<T> on, Trace trace, T value) async {
    if (on != event) throw Exception("Unknown event");
    for (final listener in _listeners.toList()) {
      // Ignore any listener errors
      try {
        await listener(trace, value);
      } catch (e) {
        trace.addEvent("listener threw error: ${e.runtimeType}");
      }
    }
  }
}

class EmitterEvent<T> {}
