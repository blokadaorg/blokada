import '../util/trace.dart';

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

class JsonTraceSpanFormat2 {
  late String traceId;
  late String spanId;
  late String name;
  late String? parentSpanId;
  late DateTime startTime;
  late DateTime endTime;
  late TraceStatus status;
  late String processID;
  late String? statusMessage;
  late List<JsonTraceField> logs;

  JsonTraceSpanFormat2({
    required this.traceId,
    required this.spanId,
    required this.name,
    required this.parentSpanId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.processID,
    required this.statusMessage,
    required this.logs,
  });

  Map<String, dynamic> toJson() => {
        "traceID": traceId,
        "spanID": spanId,
        "operationName": name,
        "references": (parentSpanId != null)
            ? [
                {
                  "refType": "CHILD_OF",
                  "traceID": parentSpanId,
                  "spanID": parentSpanId
                }
              ]
            : null,
        "startTime": startTime.microsecondsSinceEpoch,
        "duration":
            endTime.microsecondsSinceEpoch - startTime.microsecondsSinceEpoch,
        "tags": [
          // JsonTraceField2(
          //   "otel.status_code",
          //   status == TraceStatus.ok ? "OK" : "ERROR",
          // ),
          // JsonTraceField2("otel.status_description", statusMessage ?? ""),
          if (status != TraceStatus.ok)
            JsonTraceField2("error", true, type: "bool"),
        ].map((it) => it.toJson()).toList(),
        "processID": processID,
        "logs": logs.map((it) => it.toJson()).toList(),
        "warnings": statusMessage == null ? null : [statusMessage],
      };
}

class JsonTraceField {
  late String key;
  late String value;
  late DateTime timestamp;

  JsonTraceField(this.key, this.value, this.timestamp);

  Map<String, dynamic> toJson() => {
        "timestamp": timestamp.microsecondsSinceEpoch * 1000,
        "fields": [
          {
            "key": key,
            "type": "string",
            "value": value,
          }
        ]
      };
}

class JsonTraceField2 {
  late String key;
  late dynamic value;
  late String type;

  JsonTraceField2(this.key, this.value, {this.type = "string"});

  Map<String, dynamic> toJson() => {"key": key, "value": value, "type": type};
}

class JsonTraceBatch {
  late String traceID;
  late List<JsonTraceSpanFormat2> spans;
  late List<String> processes;

  JsonTraceBatch({
    required this.traceID,
    required this.spans,
    required this.processes,
  });

  Map<String, dynamic> toJson() => {
        "traceID": traceID,
        "spans": spans.map((it) => it.toJson()).toList(),
        "processes": {
          for (var item in processes) item: {"serviceName": item}
        },
      };
}
