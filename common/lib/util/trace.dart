import 'package:common/logger/logger.dart';

abstract class Trace {
  Trace start(String module, String name, {bool? important});
  end();
  endWithFailure(Exception e, StackTrace s);
  endWithFatal(Error e, StackTrace s);

  void addAttribute(String key, dynamic value, {bool sensitive = false});
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

abstract class TraceFactory {
  newTrace(String module, String name, {bool? important});
}

String shortString(String s, {int length = 64}) {
  if (s.length > length) {
    return "${s.substring(0, length).replaceAll("\n", "").trim()}[...]";
  } else {
    return s.replaceAll("\n", "").trim();
  }
}

mixin Startable {
  Future<void> start(Marker m);
}
