import 'dart:math';

import 'package:flex_color_scheme/flex_color_scheme.dart';

const _verbose = true;

abstract class Trace {
  Trace start(String name, {bool? important});
  end();
  endWithFailure(Exception e, StackTrace s);
  endWithFatal(Error e, StackTrace s);

  void addAttribute(String key, dynamic value);
  void setAttributes(Map<String, dynamic> attributes);

  void addEvent(String message, {Map<String, dynamic>? params});
}

enum TraceStatus {
  unset,
  ok,
  efault, // An expected error, but use a less common word for easier grepping
  efatal // An unexpected error, usually a bug
}

class TraceEvent {
  final String message;
  final Map<String, dynamic>? params;
  final DateTime time;

  TraceEvent(this.message, this.params, this.time);
}

class DebugTrace extends Trace {
  final DebugTrace? _parent;
  final String _name;
  final bool _important;
  final DateTime _start;
  DateTime? _end;

  TraceStatus _status = TraceStatus.unset;
  Exception? _statusException;
  Error? _statusFatal;
  StackTrace? _statusStackTrace;
  bool _stackPrintedByChild = false;

  Map<String, dynamic> _attributes = {};
  final List<TraceEvent> _events = [];
  int _unfinishedChildren = 0;

  DebugTrace._(this._parent, String name, bool? important)
      : _name = _makeName(_parent, name),
        _important = important ?? _parent?._important ?? false,
        _start = DateTime.now() {
    _printStart();
  }

  DebugTrace.as(String name, {bool? important}) : this._(null, name, important);

  @override
  Trace start(String name, {bool? important}) {
    _unfinishedChildren += 1;
    Trace? up = _parent;
    while (up != null && up is DebugTrace) {
      up._unfinishedChildren += 1;
      up = up._parent;
    }

    return DebugTrace._(this, name, important);
  }

  @override
  end() {
    if (_end != null) throw StateError("Trace $_name already ended");
    if (_unfinishedChildren != 0) {
      throw StateError("Trace $_name has unfinished children");
    }
    _end = DateTime.now();
    _status = TraceStatus.ok;
    _printEnd();

    Trace? up = _parent;
    while (up != null && up is DebugTrace) {
      up._unfinishedChildren -= 1;
      up = up._parent;
    }
  }

  @override
  endWithFailure(Exception e, StackTrace s) {
    if (_end != null) throw StateError("Trace $_name already ended");
    if (_unfinishedChildren != 0) {
      throw StateError("Trace $_name has unfinished children");
    }
    _end = DateTime.now();
    _status = TraceStatus.efault;
    _statusException = e;
    _statusStackTrace = s;
    _printEnd();

    Trace? up = _parent;
    while (up != null && up is DebugTrace) {
      up._unfinishedChildren -= 1;
      up = up._parent;
    }
  }

  @override
  endWithFatal(Error e, StackTrace s) {
    if (_end != null) throw StateError("Trace $_name already ended");
    if (_unfinishedChildren != 0) {
      throw StateError("Trace $_name has unfinished children");
    }
    _end = DateTime.now();
    _status = TraceStatus.efatal;
    _statusFatal = e;
    _statusStackTrace = s;
    _printEnd();

    Trace? up = _parent;
    while (up != null && up is DebugTrace) {
      up._unfinishedChildren -= 1;
      up = up._parent;
    }
  }

  @override
  void addAttribute(String key, value) {
    _attributes[key] = value;
  }

  @override
  void setAttributes(Map<String, dynamic> attributes) {
    _attributes = attributes;
  }

  @override
  void addEvent(String message, {Map<String, dynamic>? params}) {
    final event = TraceEvent(message, params, DateTime.now());
    _events.add(event);
    _printEvent(event);
  }

  void _printStart() {
    if (_important || _verbose) {
      print("$_start [$_name]");
    }
  }

  void _printEvent(TraceEvent event) {
    print("${event.time} [$_name] event: ${event.message}");
    if (event.params?.isNotEmpty ?? false) {
      print("${event.time} [$_name] event params: ${event.params}");
    }
  }

  void _printEnd() {
    if (_attributes.isNotEmpty) {
      print("$_end [$_name] $_attributes");
    }

    final time = _end!.difference(_start).inMilliseconds;
    final status = _status.name.toUpperCase();
    if (time > 50) {
      if (_important ||
          _parent == null ||
          _status != TraceStatus.ok ||
          _verbose) {
        print("$_end [$_name] $status ($time ms)");
      }
    } else if (_important ||
        _parent == null ||
        _status != TraceStatus.ok ||
        _verbose) {
      print("$_end [$_name] $status");
    }

    if (_status == TraceStatus.efatal) {
      print("$_end [$_name] ${_shortError(_statusFatal)}");
      if (!_stackPrintedByChild) {
        print("FATAL FULL MESSAGE:\n$_statusFatal");
        print("*** FATAL STACK ***\n$_statusStackTrace\n*** FATAL STACK ***");
        _parent?._stackPrintedByChild = true;
      }
    } else if (_status == TraceStatus.efault) {
      print("$_end [$_name] ${_shortError(_statusException)}");
      if (!_stackPrintedByChild) {
        print("FAULT FULL MESSAGE:\n$_statusException");
        _parent?._stackPrintedByChild = true;
      }
    }
  }
}

String _makeName(Trace? parent, String name) {
  if (parent == null) return name;
  if (parent is DebugTrace) {
    return "${parent._name}:$name";
  }
  throw StateError("Unknown parent type");
}

const _shortErrorLength = 127;
String _shortError(Object? e) {
  final s = _mapError(e);
  if (s.length > _shortErrorLength) {
    return "${s.substring(0, _shortErrorLength).replaceAll("\n", "").trim()} [...]";
  } else {
    return s.replaceAll("\n", "").trim();
  }
}

String _mapError(Object? e) {
  if (e == null) return "[no error object]";
  final s = e.toString();
  if (s.contains("instanceFactory != null")) {
    final type = s.split(" type ")[1].split(" is not registered ")[0];
    return "Missing dependency for $type";
  } else {
    return s;
  }
}

mixin Traceable {
  // Wrap the function with tracing of a successful or failure execution.
  // Rethrow on Exception. Note that Errors are not traced.
  Future<T> traceWith<T>(
      Trace parentTrace, String name, Future<T> Function(Trace trace) fn,
      {Future<T> Function(Trace trace)? fallback, bool? important}) async {
    final trace = parentTrace.start(name, important: important);
    try {
      final result = await fn(trace);
      trace.end();
      return result;
    } on Exception catch (e, s) {
      if (fallback == null) {
        trace.endWithFailure(e, s);
        rethrow;
      }

      try {
        final result = await fallback(trace);
        trace.end();
        return result;
      } on Exception catch (e, s) {
        trace.endWithFailure(e, s);
        rethrow;
      } on Error catch (e, s) {
        trace.endWithFatal(e, s);
        rethrow;
      }
    } on Error catch (e, s) {
      trace.endWithFatal(e, s);
      rethrow;
    }
  }

  // Wrap the function with tracing of a successful or failure execution.
  // Do not rethrow.
  // Starts a root tracing. Used for top-level callbacks from reactions or binders.
  traceAs(String name, Future Function(Trace trace) fn,
      {Future Function(Trace trace, Exception e)? fallback,
      Future Function(Trace trace)? deferred,
      bool important = false}) async {
    final trace = DebugTrace.as("$runtimeType:$name", important: important);
    try {
      await fn(trace);
      if (deferred != null) {
        await deferred(trace);
      }
      trace.end();
    } on Exception catch (e, s) {
      if (fallback == null) {
        if (deferred != null) {
          await deferred(trace);
        }
        trace.endWithFailure(e, s);
        return;
      }

      try {
        await fallback(trace, e);
        if (deferred != null) {
          await deferred(trace);
        }
        trace.end();
      } on Exception catch (e, s) {
        if (deferred != null) {
          await deferred(trace);
        }
        trace.endWithFailure(e, s);
      } on Error catch (e, s) {
        if (deferred != null) {
          await deferred(trace);
        }
        trace.endWithFatal(e, s);
      }
    } on Error catch (e, s) {
      if (deferred != null) {
        await deferred(trace);
      }
      trace.endWithFatal(e, s);
    }
  }
}
