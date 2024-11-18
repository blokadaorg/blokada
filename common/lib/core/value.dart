part of 'core.dart';

class NullableValue<T> {
  late T? _value;
  bool _resolved = false;

  T? get now {
    try {
      return _value;
    } catch (_) {
      throw Exception("NullableValue $runtimeType is not resolved yet.");
    }
  }

  Future<T?> fetch(Marker m) async {
    try {
      if (!_resolved) {
        // Also broadcasts to stream
        change(m, await doLoad());
      }
      return _value;
    } catch (e) {
      throw Exception("NullableValue $runtimeType failed to load: $e.");
    }
  }

  Future<T?> doLoad() => throw Exception("Value $runtimeType does not resolve");
  doSave(T? value) async => {};

  // Value changes can be observed by many
  final _stream = StreamController<NullableValueUpdate<T>>.broadcast();
  Stream<NullableValueUpdate<T>> get onChange => _stream.stream;

  change(Marker m, T? newValue) {
    if (!_resolved || _value != newValue) {
      try {
        final update =
            NullableValueUpdate(_resolved ? _value : null, newValue, m);
        _resolved = true;
        _value = newValue;
        _stream.sink.add(update);
        doSave(newValue);
      } catch (e) {
        throw Exception("NullableValue $runtimeType failed to save: $e.");
      }
    }
  }

  void dispose() {
    _stream.close();
  }
}

abstract class AsyncValue<T> {
  late T _value;
  bool _resolving = false;
  bool resolved = false;

  T get now {
    try {
      return _value;
    } catch (_) {
      throw Exception("Value $runtimeType is not resolved yet.");
    }
  }

  Future<T> fetch(Marker m) async {
    if (!_resolving) {
      _resolving = true;
      // Also broadcasts to stream
      change(m, await doLoad());
      resolved = true;
    }
    return _value!;
  }

  Future<T> doLoad() => throw Exception("Value $runtimeType does not resolve");
  doSave(T value) async => {};

  final _stream = StreamController<ValueUpdate<T>>.broadcast();
  Stream<ValueUpdate<T>> get onChange => _stream.stream;

  change(Marker m, T newValue) {
    try {
      if (_value != newValue) {
        final update = ValueUpdate(resolved ? _value : null, newValue, m);
        resolved = true;
        _value = newValue;
        _stream.sink.add(update);
        doSave(newValue);
      }
    } catch (_) {
      final update = ValueUpdate(resolved ? _value : null, newValue, m);
      resolved = true;
      _value = newValue;
      _stream.sink.add(update);
      doSave(newValue);
    }
  }

  void dispose() {
    _stream.close();
  }
}

abstract class Value<T> {
  late T _value;
  bool _resolved = false;

  T get now {
    if (!_resolved) {
      _resolved = true;
      // Also broadcasts to stream
      now = doLoad();
    }
    return _value!;
  }

  T doLoad() => throw Exception("Value $runtimeType does not resolve");
  doSave(T value) async => {};

  final _stream = StreamController<T>.broadcast();
  Stream<T> get onChange => _stream.stream;

  set now(T newValue) {
    _resolved = true;
    try {
      if (_value != newValue) {
        _value = newValue;
        _stream.sink.add(newValue);
        doSave(newValue);
      }
    } catch (_) {
      _value = newValue;
      _stream.sink.add(newValue);
      doSave(newValue);
    }
  }

  void dispose() {
    _stream.close();
  }
}

class NullableValueUpdate<T> {
  final T? old;
  final T? now;
  final Marker m;

  NullableValueUpdate(this.old, this.now, this.m);
}

class ValueUpdate<T> {
  final T? old;
  final T now;
  final Marker m;

  ValueUpdate(this.old, this.now, this.m);
}
