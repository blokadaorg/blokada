import 'dart:async';
import 'dart:convert';
import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../util/config.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'channel.pg.dart';
import 'json.dart';
import 'tracer.dart';

final _collector = dep<TraceCollector>();

class DefaultTrace with Trace {
  final String _id;
  final String _module;
  final DefaultTrace? _parent;
  final String _rootId;
  final String _name;
  final bool _important;
  final DateTime _start;
  DateTime? _end;

  TraceStatus _status = TraceStatus.unset;
  String? _statusError;
  StackTrace? _statusStackTrace;
  bool _stackPrintedByChild = false;

  Map<String, dynamic> _attributes = {};
  final List<String> _sensitiveAttributeKeys = [];
  final List<TraceEvent> _events = [];
  int _unfinishedChildren = 0;

  DefaultTrace._(
    this._id,
    this._parent,
    this._module,
    this._name,
    bool? important,
  )   : _important = important ?? _parent?._important ?? false,
        _start = DateTime.now(),
        _rootId = _parent?._rootId ?? _id {
    _collector.onStart(this);
  }

  DefaultTrace.as(String id, String module, String name, {bool? important})
      : this._(id, null, module, name, important);

  @override
  Trace start(String module, String name, {bool? important}) {
    _unfinishedChildren += 1;
    Trace? up = _parent;
    while (up != null && up is DefaultTrace) {
      up._unfinishedChildren += 1;
      up = up._parent;
    }

    return DefaultTrace._(generateTraceId(8), this, module, name, important);
  }

  @override
  end() async {
    if (_end != null) throw StateError("Trace $_name already ended");
    if (_unfinishedChildren != 0) {
      throw StateError(
          "Trace $_name has $_unfinishedChildren unfinished children");
    }
    _end = DateTime.now();
    _status = TraceStatus.ok;

    Trace? up = _parent;
    while (up != null && up is DefaultTrace) {
      up._unfinishedChildren -= 1;
      up = up._parent;
    }

    await _collector.onEnd(this);
  }

  @override
  endWithFailure(Exception e, StackTrace s) async {
    if (_end != null) throw StateError("Trace $_name already ended");
    if (_unfinishedChildren != 0) {
      throw e; // Do not hide original error
    }
    _end = DateTime.now();
    _status = TraceStatus.efault;
    _statusError = _mapError(e);
    _statusStackTrace = s;

    Trace? up = _parent;
    while (up != null && up is DefaultTrace) {
      up._unfinishedChildren -= 1;
      up = up._parent;
    }

    await _collector.onEnd(this);
  }

  @override
  endWithFatal(Error e, StackTrace s) async {
    if (_end != null) throw StateError("Trace $_name already ended");
    if (_unfinishedChildren != 0) {
      throw e; // Do not hide original error
    }
    _end = DateTime.now();
    _status = TraceStatus.efatal;
    _statusError = _mapError(e);
    _statusStackTrace = s;

    Trace? up = _parent;
    while (up != null && up is DefaultTrace) {
      up._unfinishedChildren -= 1;
      up = up._parent;
    }

    await _collector.onEnd(this);
  }

  @override
  void addAttribute(String key, value, {bool sensitive = false}) {
    _attributes[key] = value;
    if (sensitive) {
      _sensitiveAttributeKeys.add(key);
    }
  }

  @override
  void setAttributes(Map<String, dynamic> attributes) {
    _attributes = attributes;
  }

  @override
  void addEvent(String message, {Map<String, dynamic>? params}) async {
    final event = TraceEvent(message, params, DateTime.now());
    _events.add(event);
    await _collector.onEvent(this, event);
  }
}

class StdoutTraceCollector with TraceCollector {
  final _verbose = true;

  @override
  onStart(DefaultTrace t) {
    if (t._important || _verbose) {
      print("${t._start} [${_getName(t)}]");
    }
  }

  @override
  onEnd(DefaultTrace t) {
    if (t._attributes.isNotEmpty) {
      print("${t._end} [${_getName(t)}] ${t._attributes}");
    }

    final time = t._end!.difference(t._start).inMilliseconds;
    final status = t._status.name.toUpperCase();
    if (time > 50) {
      if (t._important ||
          t._parent == null ||
          t._status != TraceStatus.ok ||
          _verbose) {
        print("${t._end} [${_getName(t)}] $status ($time ms)");
      }
    } else if (t._important ||
        t._parent == null ||
        t._status != TraceStatus.ok ||
        _verbose) {
      print("${t._end} [${_getName(t)}] $status");
    }

    if (t._status == TraceStatus.efatal || t._status == TraceStatus.efault) {
      print("${t._end} [${_getName(t)}] ${_shortError(t._statusError)}");
      if (!t._stackPrintedByChild) {
        print("FULL MESSAGE:\n${t._statusError}");
        print("*** STACK ***\n${t._statusStackTrace}\n*** STACK ***");
        t._parent?._stackPrintedByChild = true;
      }
    }
  }

  @override
  onEvent(DefaultTrace t, TraceEvent e) {
    print("${e.time} [${_getName(t)}] event: ${e.message}");
    if (e.params?.isNotEmpty ?? false) {
      print("${e.time} [${_getName(t)}] event params: ${e.params}");
    }
  }

  String _getName(DefaultTrace t) {
    if (t._parent == null) return t._name;
    String previous = "";
    if (t._parent?._parent != null) previous = "...:";
    return "$previous${t._parent!._name}:${t._name}";
  }

  String _shortError(Object? e) {
    return shortString(_mapError(e));
  }
}

String _mapError(Object? e) {
  if (e == null) return "[no error object]";
  if (e is PlatformException) {
    final msg = e.code;
    return "PlatformException($msg)";
  } else {
    final s = e.toString();
    if (s.contains("instanceFactory != null")) {
      final type = s.split(" type ")[1].split(" is not registered ")[0];
      return "Missing dependency for $type";
    } else {
      return s;
    }
  }
}

class JsonTraceCollector with TraceCollector {
  final bool immediate;
  final Uri uri;

  final Map<String, DefaultTrace> _tracesById = {};
  final Map<String, List<DefaultTrace>> _tracesByModule = {};

  Timer _sendTimer = Timer(Duration.zero, () {});

  JsonTraceCollector({required this.immediate, required this.uri}) {
    print("Runtime traceId: $runtimeTraceId");
  }

  @override
  onStart(DefaultTrace t) {
    if (_tracesById.containsKey(t._id)) {
      print("Trace id collision: ${t._id}. Ignoring trace");
    } else {
      _tracesById[t._id] = t;
      if (!_tracesByModule.containsKey(t._module)) {
        _tracesByModule[t._module] = [t];
      } else {
        _tracesByModule[t._module]!.add(t);
      }
    }
  }

  @override
  onEnd(DefaultTrace t) async {
    (immediate) ? await sendTraces() : _manageTracesQueue();
  }

  @override
  onEvent(DefaultTrace t, TraceEvent e) {
    // Noop for this collector
  }

  _manageTracesQueue() {
    if (cfg.debugSendTracesUntil?.isAfter(DateTime.now()) ?? false) {
      _sendTimer.cancel();
      _sendTimer = Timer(const Duration(seconds: 3), sendTraces);
    } else if (_tracesById.length > 10000) {
      _tracesById.clear();
      _tracesByModule.clear();
      print("Dropped traces queue");
    }
  }

  sendTraces() async {
    final modules = _tracesByModule.keys.toList();
    for (var module in modules) {
      // Send only modules with all traces ended
      final traces = _tracesByModule[module];
      if (!(traces?.any((e) => e._end == null) ?? true)) {
        await _sendBatch(module, traces!);
      }
    }

    if (modules.isNotEmpty) {
      print(
          "$runtimeType done sending traces for ${modules.length} modules ($runtimeTraceId)");
    }
  }

  _sendBatch(String module, List<DefaultTrace> traces) async {
    try {
      final jsonTraces = traces.map((t) => convertTrace(module, t)).toList();
      final json = jsonEncode(jsonTraces);

      for (var t in traces) {
        _tracesById.remove(t._id);
      }
      _tracesByModule.remove(module);

      await send(module, wrapSpans(module, json));
      runtimeLastError = null;
    } catch (e, s) {
      print("Error sending ${traces.length} traces of module $module: $e");
      runtimeLastError = e.toString();
    }
  }

  Map<String, dynamic> convertTrace(String module, DefaultTrace t) {
    final span = JsonTraceSpan(
      traceId: runtimeTraceId,
      spanId: t._id,
      parentSpanId: t._parent?._id,
      name: t._name,
      startTime: t._start,
      endTime: t._end!,
      status: t._status,
      statusMessage: t._statusError,
      attributes: t._attributes
          .filter((it) => !t._sensitiveAttributeKeys.contains(it.key))
          .entries
          .map((e) => JsonTraceAttribute(e.key, e.value.toString()))
          .toList(),
      events: t._events.map((e) => JsonTraceEvent(e.message, e.time)).toList() +
          // We send attributes as events because they are more readable in Jaeger
          t._attributes
              .filter((it) => !t._sensitiveAttributeKeys.contains(it.key))
              .entries
              .map((e) => JsonTraceEvent("${e.key}: ${e.value}", t._start))
              .toList(),
    );
    return span.toJson();
  }

  String wrapSpans(String module, String spans) {
    return '''
{
  "resource_spans": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {
              "stringValue": "$module"
            }
          }
        ]
      },
      "scope_spans": [
        {
          "scope": {
            "name": "org.blokada.ios",
            "version": "6.0.0",
            "attributes": [
              {
                "key": "my.scope.attribute",
                "value": {
                  "stringValue": "some scope attribute"
                }
              }
            ]
          },
          "spans": $spans
        }
      ]
    }
  ]
}''';
  }

  send(String module, String batch) async {
    final response = await http.post(uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: batch);

    if (response.statusCode != 200) {
      throw Exception(
          "Failed to send traces: ${response.statusCode} ${response.body}");
    }
  }
}

class FileTraceCollector extends TraceCollector {
  late final _ops = dep<TracerOps>();

  Timer _sendTimer = Timer(Duration.zero, () {});

  bool _fileCreated = false;

  final Map<String, DefaultTrace> _tracesById = {};
  final Map<String, List<DefaultTrace>> _tracesByRoot = {};

  @override
  onStart(DefaultTrace t) {
    if (_tracesById.containsKey(t._id)) {
      print("Trace id collision: ${t._id}. Ignoring trace");
    } else {
      _tracesById[t._id] = t;
      if (t._parent == null) {
        _tracesByRoot[t._id] = [t];
      } else {
        _tracesByRoot[t._rootId]!.add(t);
      }
    }
  }

  @override
  onEnd(DefaultTrace t) async {
    if (t._parent == null) _manageTracesQueue();
  }

  @override
  onEvent(DefaultTrace t, TraceEvent e) {
    // Noop for this collector
  }

  _manageTracesQueue() {
    _sendTimer.cancel();
    _sendTimer = Timer(const Duration(seconds: 3), sendTraces);
  }

  sendTraces() async {
    for (var traceId in _tracesByRoot.keys.toList()) {
      // Send only modules with all traces ended
      final traces = _tracesByRoot[traceId];
      if (!(traces?.any((e) => e._end == null) ?? true)) {
        await _sendBatch(traceId);
      }
    }
  }

  _sendBatch(String rootId) async {
    try {
      final traces = _tracesByRoot[rootId]!;
      final processes = traces.map((t) => t._module).toSet().toList();
      final jsonTraces = traces.map((t) => _convertTrace(t)).toList();
      final json = jsonEncode(JsonTraceBatch(
              traceID: rootId, spans: jsonTraces, processes: processes)
          .toJson());

      for (var t in traces) {
        _tracesById.remove(t._id);
      }
      _tracesByRoot.remove(rootId);

      await _send(json);
      print("$runtimeType done sending ${traces.length} traces for $rootId");
    } catch (e, s) {
      print("Error sending traces for $rootId: $e");
      print(s);
    }
  }

  _send(String batch) async {
    if (!_fileCreated) {
      const template = '''
{"data":[
  \t\t\t
]}''';

      await _ops.doStartFile(template);
      _fileCreated = true;

      batch = "  $batch\n";
    } else {
      batch = "  , $batch\n";
    }

    await _ops.doSaveBatch(batch, "\t\t\t");
  }

  JsonTraceSpanFormat2 _convertTrace(DefaultTrace t) {
    return JsonTraceSpanFormat2(
      traceId: t._rootId,
      spanId: t._id,
      processID: t._module,
      parentSpanId: t._parent?._id,
      name: t._name,
      startTime: t._start,
      endTime: t._end!,
      status: t._status,
      statusMessage: t._statusError,
      logs: t._events
              .map((e) => JsonTraceField("event", e.message, e.time))
              .toList() +
          t._attributes
              .filter((it) => !t._sensitiveAttributeKeys.contains(it.key))
              .entries
              .map((e) => JsonTraceField(e.key, e.value.toString(), t._start))
              .toList(),
    );
  }
}

class NoopTraceCollector with TraceCollector {
  @override
  onEnd(DefaultTrace t) {}

  @override
  onEvent(DefaultTrace t, TraceEvent e) {}

  @override
  onStart(DefaultTrace t) {}
}
