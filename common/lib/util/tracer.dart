import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'di.dart';
import 'trace.dart';

final _collector = dep<TraceCollector>();

class DefaultTracer with Tracer, Dependable {
  @override
  attach() {
    depend<Tracer>(this);
    depend<TraceCollector>(DefaultCollector());
  }

  @override
  newTrace(String module, String name, {bool? important}) {
    return DefaultTrace.as(_generateId(8), module, name, important: important);
  }
}

class DefaultTrace with Trace {
  final String _id;
  final String _module;
  final DefaultTrace? _parent;
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

  DefaultTrace._(
    this._id,
    this._parent,
    this._module,
    this._name,
    bool? important,
  )   : _important = important ?? _parent?._important ?? false,
        _start = DateTime.now() {
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

    return DefaultTrace._(_generateId(8), this, module, name, important);
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
    _statusException = e;
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
    _statusFatal = e;
    _statusStackTrace = s;

    Trace? up = _parent;
    while (up != null && up is DefaultTrace) {
      up._unfinishedChildren -= 1;
      up = up._parent;
    }

    await _collector.onEnd(this);
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
  void addEvent(String message, {Map<String, dynamic>? params}) async {
    final event = TraceEvent(message, params, DateTime.now());
    _events.add(event);
    await _collector.onEvent(this, event);
  }
}

abstract class TraceCollector {
  onStart(DefaultTrace t);
  onEnd(DefaultTrace t);
  onEvent(DefaultTrace t, TraceEvent e);
}

class StdoutCollector with TraceCollector {
  final _verbose = true;
  final _shortErrorLength = 127;

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

    if (t._status == TraceStatus.efatal) {
      print("${t._end} [${_getName(t)}] ${_shortError(t._statusFatal)}");
      if (!t._stackPrintedByChild) {
        print("FATAL FULL MESSAGE:\n${t._statusFatal}");
        print(
            "*** FATAL STACK ***\n${t._statusStackTrace}\n*** FATAL STACK ***");
        t._parent?._stackPrintedByChild = true;
      }
    } else if (t._status == TraceStatus.efault) {
      print("${t._end} [${_getName(t)}] ${_shortError(t._statusException)}");
      if (!t._stackPrintedByChild) {
        print("FAULT FULL MESSAGE:\n${t._statusException}");
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
}

final _random = Random.secure();
String _generateId(int len) {
  final values = List<int>.generate(len, (i) => _random.nextInt(256));
  return values.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

class ApiCollector with TraceCollector {
  // Common parent trace id for the whole app runtime
  late final _runtimeTraceId = _generateId(16);

  final Map<String, DefaultTrace> _tracesById = {};
  final Map<String, List<DefaultTrace>> _tracesByModule = {};

  Timer _sendTimer = Timer(Duration.zero, () {});

  final bool _inTest;

  ApiCollector({bool inTest = false}) : _inTest = inTest {
    print("Runtime traceId: $_runtimeTraceId");
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
    (_inTest) ? await _sendTraces() : _postponeTimer();
  }

  @override
  onEvent(DefaultTrace t, TraceEvent e) {
    // Noop for this collector
  }

  _postponeTimer() {
    _sendTimer.cancel();
    _sendTimer = Timer(const Duration(seconds: 3), _sendTraces);
  }

  _sendTraces() async {
    final modules = _tracesByModule.keys.toList();
    for (var module in modules) {
      // Send only modules with all traces ended
      final traces = _tracesByModule[module];
      if (!(traces?.any((e) => e._end == null) ?? true)) {
        await _sendBatch(module, traces!);
      }
    }
  }

  _sendBatch(String module, List<DefaultTrace> traces) async {
    try {
      final jsonTraces = traces.map((t) => _convertTrace(t)).toList();
      final json = jsonEncode(jsonTraces);

      for (var t in traces) {
        _tracesById.remove(t._id);
      }
      _tracesByModule.remove(module);

      await _post(module, json);
      print(
          "Sent ${traces.length} traces of module $module ($_runtimeTraceId)");
    } catch (e, s) {
      print("Error sending ${traces.length} traces of module $module: $e");
    }
  }

  Map<String, dynamic> _convertTrace(DefaultTrace t) {
    final span = JsonTraceSpan(
      traceId: _runtimeTraceId,
      spanId: t._id,
      parentSpanId: t._parent?._id,
      name: t._name,
      startTime: t._start,
      endTime: t._end!,
      status: t._status,
      statusMessage: t._status == TraceStatus.efatal
          ? t._statusFatal.toString()
          : t._statusException.toString(),
      attributes: t._attributes.entries
          .map((e) => JsonTraceAttribute(e.key, e.value.toString()))
          .toList(),
      events: t._events.map((e) => JsonTraceEvent(e.message, e.time)).toList() +
          // We send attributes as events because they are more readable in Jaeger
          t._attributes.entries
              .map((e) => JsonTraceEvent("${e.key}: ${e.value}", t._start))
              .toList(),
    );
    return span.toJson();
  }

  _post(String module, String spans) async {
    final response = await http.post(
      Uri.parse('http://192.168.101.107:4318/v1/traces'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: '''
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
}
    ''',
    );

    if (response.statusCode != 200) {
      throw Exception(
          "Failed to send traces: ${response.statusCode} ${response.body}");
    }
  }
}

class DefaultCollector with TraceCollector {
  final _stdout = StdoutCollector();
  late final TraceCollector _api;

  DefaultCollector({bool inTest = false}) {
    _api = ApiCollector(inTest: inTest);
  }

  @override
  onStart(DefaultTrace t) async {
    await _stdout.onStart(t);
    await _api.onStart(t);
  }

  @override
  onEnd(DefaultTrace t) async {
    await _stdout.onEnd(t);
    await _api.onEnd(t);
  }

  @override
  onEvent(DefaultTrace t, TraceEvent e) async {
    await _stdout.onEvent(t, e);
  }
}

class JsonTraceSpan {
  late String traceId;
  late String spanId;
  late String? parentSpanId;
  late String name;
  late DateTime startTime;
  late DateTime endTime;
  late TraceStatus status;
  late String? statusMessage;
  late List<JsonTraceAttribute> attributes;
  late List<JsonTraceEvent> events;

  JsonTraceSpan({
    required this.traceId,
    required this.spanId,
    required this.parentSpanId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.statusMessage,
    required this.attributes,
    required this.events,
  });

  Map<String, dynamic> toJson() => {
        "traceId": traceId,
        "spanId": spanId,
        "parentSpanId": parentSpanId,
        "name": name,
        "startTimeUnixNano": startTime.microsecondsSinceEpoch * 1000,
        "endTimeUnixNano": endTime.microsecondsSinceEpoch * 1000,
        "status": {
          "code": status == TraceStatus.ok ? 1 : 2,
          "message": statusMessage
        },
        "kind": 1, // Internal
        "attributes": attributes.map((it) => it.toJson()).toList(),
        "events": events.map((it) => it.toJson()).toList(),
      };
}

class JsonTraceAttribute {
  late String key;
  late String value;

  JsonTraceAttribute(this.key, this.value);

  Map<String, dynamic> toJson() => {
        "key": key,
        "value": {"stringValue": value},
      };
}

class JsonTraceEvent {
  late String name;
  late DateTime time;

  JsonTraceEvent(this.name, this.time);

  Map<String, dynamic> toJson() => {
        "name": name,
        "timeUnixNano": time.microsecondsSinceEpoch * 1000,
      };
}
