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
}
