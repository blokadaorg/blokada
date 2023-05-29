import 'di.dart';

abstract class Trace {
  Trace start(String module, String name, {bool? important});
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

abstract class Tracer {
  newTrace(String module, String name, {bool? important});
}

mixin Traceable {
  late final _tracer = dep<Tracer>();

  // Wrap the function with tracing of a successful or failure execution.
  // Rethrow on Exception or Error.
  Future<T> traceWith<T>(
    Trace parentTrace,
    String name,
    Future<T> Function(Trace trace) fn, {
    Future<T> Function(Trace trace)? fallback,
    Future Function(Trace trace)? deferred,
    bool? important,
  }) async {
    final trace =
        parentTrace.start(runtimeType.toString(), name, important: important);
    try {
      final result = await fn(trace);
      await trace.end();
      return result;
    } on Exception catch (e, s) {
      if (fallback == null) {
        await trace.endWithFailure(e, s);
        rethrow;
      }

      try {
        final result = await fallback(trace);
        await trace.end();
        return result;
      } on Exception catch (e, s) {
        await trace.endWithFailure(e, s);
        rethrow;
      } on Error catch (e, s) {
        await trace.endWithFatal(e, s);
        rethrow;
      }
    } on Error catch (e, s) {
      await trace.endWithFatal(e, s);
      rethrow;
    }
  }
}

mixin TraceOrigin {
  late final _trace = dep<Tracer>();

  traceAs(
    String name,
    Future Function(Trace trace) fn, {
    Future Function(Trace trace, Exception e)? fallback,
    Future Function(Trace trace)? deferred,
    bool important = false,
  }) async {
    final trace =
        _trace.newTrace(runtimeType.toString(), name, important: important);
    try {
      await fn(trace);
      if (deferred != null) {
        await deferred(trace);
      }
      await trace.end();
    } on Exception catch (e, s) {
      if (fallback == null) {
        if (deferred != null) {
          await deferred(trace);
        }
        await trace.endWithFailure(e, s);
        return;
      }

      try {
        await fallback(trace, e);
        if (deferred != null) {
          await deferred(trace);
        }
        await trace.end();
      } on Exception catch (e, s) {
        if (deferred != null) {
          await deferred(trace);
        }
        await trace.endWithFailure(e, s);
      } on Error catch (e, s) {
        if (deferred != null) {
          await deferred(trace);
        }
        await trace.endWithFatal(e, s);
      }
    } on Error catch (e, s) {
      if (deferred != null) {
        await deferred(trace);
      }
      await trace.endWithFatal(e, s);
    }
  }
}
