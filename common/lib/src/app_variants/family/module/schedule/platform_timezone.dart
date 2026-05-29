import 'package:flutter/services.dart';

/// Best-effort IANA timezone identifier (e.g. "Europe/Stockholm") for this
/// device.
///
/// The api requires an IANA zone id. Dart's `DateTime.timeZoneName` only
/// exposes an abbreviation ("CEST"), which the backend rejects with a 400, so
/// we ask the platform (via the shared `org.blokada/flavor` channel) for the
/// real IANA id. If it can't provide an IANA-shaped value (or the channel is
/// unavailable, e.g. in tests), fall back to UTC so a schedule save never
/// fails on the timezone field.
///
/// Shared by both the interactive save path ([ScheduleActor.saveSchedule])
/// and the kid-device seed path ([DeviceActor._seedScheduleForNewDevice])
/// so they resolve the timezone identically.
Future<String> platformTimezone() async {
  const channel = MethodChannel('org.blokada/flavor');
  try {
    final tz = await channel.invokeMethod<String>('getTimezone');
    if (tz != null && tz.contains('/')) return tz;
  } catch (_) {}
  final name = DateTime.now().timeZoneName;
  return name.contains('/') ? name : 'UTC';
}
