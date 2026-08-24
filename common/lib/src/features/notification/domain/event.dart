part of 'notification.dart';

class FcmEvent {
  final String version;
  final String type;
  final String eventId;
  final String? scheduleHint;
  final String? extras;

  FcmEvent({
    required this.version,
    required this.type,
    required this.eventId,
    required this.scheduleHint,
    required this.extras,
  });

  factory FcmEvent.fromJson(Map<String, dynamic> json) {
    return FcmEvent(
      version: (json['v'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      eventId: (json['event_id'] ?? '').toString(),
      scheduleHint: json['schedule_hint']?.toString(),
      extras: json['extras']?.toString(),
    );
  }

  /// Server-supplied extras (a JSON object encoded as a string). Empty when
  /// absent or malformed; callers treat every value as optional.
  Map<String, String> get extrasMap {
    final raw = extras;
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return const {};
  }
}
