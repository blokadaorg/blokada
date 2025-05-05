part of 'core.dart';

// A simple holder that has a default value at start and then
// can be updated, with an optional save action and a stream
// to listen to changes (by many listeners).
abstract class Value<T> with Logging {
  final T Function() load;
  final Function(T)? save;
  bool sensitive;

  Stream<ValueUpdate<T>> get onChange => _stream.stream;
  final _stream = StreamController<ValueUpdate<T>>.broadcast();

  bool _resolved = false;
  late T _value;

  Value({required this.load, this.save, this.sensitive = false});

  T get now {
    if (!_resolved) {
      now = load();
      _resolved = true;
    }
    return _value!;
  }

  // Also broadcasts to stream
  set now(T newValue) {
    if (_resolved && newValue == _value) return;

    final update =
        ValueUpdate(Markers.root, _resolved ? _value : null, newValue);
    _value = newValue;
    save?.call(newValue);

    log(Markers.root).logt(
      attr: {
        "old": _resolved ? update.old : "(undefined value)",
        "now": update.now
      },
      sensitive: sensitive,
    );

    _resolved = true;
    _stream.sink.add(update);
  }

  void dispose() {
    _stream.close();
  }
}

// Similar to Value but operates asynchronously.
// Will block on read if it's not resolved yet.
abstract class AsyncValue<T> with Logging {
  Future<T> Function(Marker m)? load;
  Future<void> Function(Marker m, T)? save;
  bool sensitive;

  AsyncValue({this.sensitive = false});

  Stream<ValueUpdate<T>> get onChange => _stream.stream;
  final _stream = StreamController<ValueUpdate<T>>.broadcast();

  // Will emit changes like onChange, and also emit current value instantly
  StreamSubscription<ValueUpdate<T>> onChangeInstant(
      Function(ValueUpdate<T>) fn) {
    final stream = onChange.listen(fn);
    if (_resolved) {
      // No await, call asynchronously
      log(Markers.valueChange).trace("$runtimeType", (m) async {
        await fn(ValueUpdate(m, present, present!));
      });
    }
    return stream;
  }

  bool _resolved = false;
  bool _resolving = false;
  late T _value;

  final _debounce = Debounce(const Duration(seconds: 15));

  Future<T> now() async {
    if (_resolved) {
      return _value;
    }

    return await _waitForResolve();
  }

  T? get present {
    if (_resolved) return _value;
    return null;
  }

  Future<T> fetch(Marker m) async {
    if (_resolving) return await _waitForResolve();

    if (!_resolved && load != null) {
      _resolving = true;
      final newValue = await load!.call(m);
      await change(m, newValue);
      _resolving = false;
      return newValue;
    }

    if (!_resolved) return await _waitForResolve();

    return _value;
  }

  Future<T> _waitForResolve() async {
    _debounce.run(() => log(Markers.root).e(
          msg: "Too slow to resolve",
          err: Exception("Too slow to resolve"),
          stack: StackTrace.current,
        ));

    final completer = Completer<T>();
    late StreamSubscription subscription;
    subscription = onChange.listen((it) {
      _debounce.cancel();
      completer.complete(it.now);
      subscription.cancel();
    });
    return completer.future;
  }

  // Also broadcasts to stream
  change(Marker m, T newValue) async {
    if (_resolved && newValue == _value) {
      log(m).logt(msg: "Skipping change in async value.", attr: {
        "hashOld": _value.hashCode,
        "hashNew": newValue.hashCode,
        "resolved": _resolved,
      });
      return;
    }

    final update =
        ValueUpdate(Markers.valueChange, _resolved ? _value : null, newValue);
    _value = newValue;
    await save?.call(m, newValue);

    log(m).logt(
      attr: {
        "old": _resolved ? update.old : "(undefined async value)",
        "now": update.now
      },
      sensitive: sensitive,
    );

    _resolved = true;
    _stream.sink.add(update);
  }

  void dispose() {
    _stream.close();
  }
}

// Similar to AsyncValue but allows null.
// Will block on read if it's not resolved yet.
abstract class NullableAsyncValue<T> with Logging {
  Future<T?> Function(Marker m)? load;
  Future<void> Function(Marker m, T?)? save;
  bool sensitive;

  Stream<NullableValueUpdate<T>> get onChange => _stream.stream;
  final _stream = StreamController<NullableValueUpdate<T>>.broadcast();

  // Will emit changes like onChange, and also emit current value instantly
  StreamSubscription<NullableValueUpdate<T>> onChangeInstant(
      Function(NullableValueUpdate<T>) fn) {
    final stream = onChange.listen(fn);
    if (_resolved) {
      // No await, call asynchronously
      log(Markers.valueChange).trace("$runtimeType", (m) async {
        await fn(NullableValueUpdate(m, present, present!));
      });
    }
    return stream;
  }

  bool _resolved = false;
  bool _resolving = false;
  late T? _value;

  final _debounce = Debounce(const Duration(seconds: 15));

  NullableAsyncValue({this.load, this.save, this.sensitive = false});

  Future<T?> now() async {
    if (_resolved) {
      return _value;
    }

    return await _waitForResolve();
  }

  T? get present {
    if (_resolved) return _value;
    return null;
  }

  Future<T?> fetch(Marker m) async {
    if (_resolving) return await _waitForResolve();

    if (!_resolved && load != null) {
      _resolving = true;
      final newValue = await load!.call(m);
      await change(m, newValue);
      _resolving = false;
      return newValue;
    }

    if (!_resolved) return await _waitForResolve();

    return _value;
  }

  Future<T> _waitForResolve() async {
    _debounce.run(() => log(Markers.root).e(
          msg: "Too slow to resolve",
          err: Exception("Too slow to resolve"),
          stack: StackTrace.current,
        ));

    final completer = Completer<T>();
    late StreamSubscription subscription;
    subscription = onChange.listen((it) {
      _debounce.cancel();
      completer.complete(it.now);
      subscription.cancel();
    });
    return completer.future;
  }

  // Also broadcasts to stream
  change(Marker m, T? newValue) async {
    if (_resolved && newValue == _value) return;

    final update = NullableValueUpdate(
        Markers.valueChange, _resolved ? _value : null, newValue);
    _value = newValue;
    await save?.call(m, newValue);

    log(m).logt(
      attr: {
        "old": _resolved ? update.old : "(undefined nullable async value)",
        "now": update.now
      },
      sensitive: sensitive,
    );

    _resolved = true;
    _stream.sink.add(update);
  }

  void dispose() {
    _stream.close();
  }
}

class NullableValueUpdate<T> {
  final Marker m;
  final T? old;
  final T? now;

  NullableValueUpdate(this.m, this.old, this.now);
}

class ValueUpdate<T> {
  final Marker m;
  final T? old;
  final T now;

  ValueUpdate(this.m, this.old, this.now);
}
