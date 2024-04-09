import 'dart:async';

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

  Future<T?> fetch() async {
    try {
      if (!_resolved) {
        _resolved = true;
        // Also broadcasts to stream
        now = await doLoad();
      }
      return _value;
    } catch (e) {
      throw Exception("NullableValue $runtimeType failed to load: $e.");
    }
  }

  Future<T?> doLoad() => throw Exception("This Value object does not resolve");
  doSave(T? value) async => {};

  final _controller = StreamController<T?>.broadcast();
  Stream<T?> get onChange => _controller.stream;

  set now(T? newValue) {
    try {
      if (_value != newValue) {
        _value = newValue;
        _controller.sink.add(newValue);
        doSave(newValue);
      }
    } catch (_) {
      _value = newValue;
      _controller.sink.add(newValue);
      doSave(newValue);
    }
  }

  void dispose() {
    _controller.close();
  }
}

abstract class AsyncValue<T> {
  late T _value;
  bool _resolved = false;

  T get now {
    try {
      return _value;
    } catch (_) {
      throw Exception("Value $runtimeType is not resolved yet.");
    }
  }

  Future<T> fetch() async {
    if (!_resolved) {
      _resolved = true;
      // Also broadcasts to stream
      now = await doLoad();
    }
    return _value!;
  }

  Future<T> doLoad() => throw Exception("This Value object does not resolve");
  doSave(T value) async => {};

  final _controller = StreamController<T>.broadcast();
  Stream<T> get onChange => _controller.stream;

  set now(T newValue) {
    try {
      if (_value != newValue) {
        _value = newValue;
        _controller.sink.add(newValue);
        doSave(newValue);
      }
    } catch (_) {
      _value = newValue;
      _controller.sink.add(newValue);
      doSave(newValue);
    }
  }

  void dispose() {
    _controller.close();
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

  T doLoad() => throw Exception("This Value object does not resolve");
  doSave(T value) async => {};

  final _controller = StreamController<T>.broadcast();
  Stream<T> get onChange => _controller.stream;

  set now(T newValue) {
    try {
      if (_value != newValue) {
        _value = newValue;
        _controller.sink.add(newValue);
        doSave(newValue);
      }
    } catch (_) {
      _value = newValue;
      _controller.sink.add(newValue);
      doSave(newValue);
    }
  }

  void dispose() {
    _controller.close();
  }
}
