import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';

/// Where the device's currently-effective filtering decision comes from.
///
/// Mirrors the precedence the server enforces per DNS query; this client copy
/// is display-only (for a future "Now" status line), never a gate on traffic.
enum EffectiveSource {
  /// A manual mode override is active (`mode != on`, not yet expired).
  manualOverride,

  /// A schedule rule matches the current weekday + window.
  scheduleRule,

  /// No override and no matching rule (or schedule paused): the device's
  /// top-level Default profile applies.
  deviceDefault,
}

/// What the device is actually doing to traffic right now.
///
/// `filter` ⇒ a profile is applied (its id is on [EffectiveState.profileId]).
/// `allowAll` ⇒ the internet is fully open, no profile (manual "Allow All" /
/// `mode == off`). `blocked` ⇒ all queries dropped (manual "Block All" /
/// `mode == blocked`, or an active `block` schedule rule). The two non-filter
/// outcomes carry a null [EffectiveState.profileId].
enum EffectiveOutcome { filter, allowAll, blocked }

/// The resolved "what is in effect right now" snapshot for a device.
///
/// [profileId] names the winning profile when [outcome] is
/// [EffectiveOutcome.filter], and is null for `allowAll` / `blocked`. [until]
/// is the instant this state is known to end, when bounded: the override's
/// `mode_until`. Schedule windows are recurring and the resolver does not
/// compute their next boundary, so [until] is null for rule/default outcomes.
class EffectiveState {
  final EffectiveSource source;
  final EffectiveOutcome outcome;
  final String? profileId;
  final DateTime? until;

  const EffectiveState({
    required this.source,
    required this.outcome,
    required this.profileId,
    this.until,
  });

  bool get blocked => outcome == EffectiveOutcome.blocked;

  @override
  String toString() =>
      'EffectiveState(source: $source, outcome: $outcome, '
      'profileId: $profileId, until: $until)';
}

/// Resolve the device's effective filtering state at [now].
///
/// Precedence (matches the server / blockarust order):
/// 1. Active manual override — `mode != on` AND (`modeUntil == null` OR
///    `now < modeUntil`). `off` ("Allow All") ⇒ internet fully open, no
///    profile; `blocked` ("Block All") ⇒ all queries dropped. The override's
///    `until` is surfaced when bounded.
/// 2. First-matching schedule rule — by ISO weekday (1..7) and time window,
///    list order significant (first match wins). Skipped entirely when the
///    schedule is `paused`. A `block` rule ⇒ blocked; otherwise its profile
///    applies.
/// 3. Device Default — the top-level [JsonDevice.profileId] (filtered).
///
/// Timezone handling: window/weekday math runs in the device's [JsonDevice.timezone].
/// The app has no IANA tz database dependency (only `intl`), so this cannot do
/// a true zone+DST conversion from a UTC [now]. The caller is expected to pass
/// a [now] already expressed in the device's local wall-clock (e.g.
/// `DateTime.now()` on a device sharing the kid's zone, or a fixed local
/// instant in tests). The function reads [now]'s weekday and minute-of-day
/// directly and does not itself shift by any offset. The risk: if [now] is in a
/// different zone than the device, rule boundaries are evaluated against the
/// wrong wall clock. This is display-only and acceptable until a tz dependency
/// is added; enforcement remains server-side where the real IANA zone is known.
EffectiveState resolveEffectiveState(JsonDevice device, DateTime now) {
  // 1. Manual override.
  final modeUntil = device.modeUntil;
  final overrideActive = device.mode != JsonDeviceMode.on &&
      (modeUntil == null || now.isBefore(modeUntil));
  if (overrideActive) {
    // `off` = "Allow All" (internet open, no profile); `blocked` = "Block All".
    final outcome = device.mode == JsonDeviceMode.blocked
        ? EffectiveOutcome.blocked
        : EffectiveOutcome.allowAll;
    return EffectiveState(
      source: EffectiveSource.manualOverride,
      outcome: outcome,
      profileId: null,
      until: modeUntil,
    );
  }

  // 2. Schedule rule (only when a schedule exists and is not paused).
  final schedule = device.schedule;
  if (schedule != null && !schedule.paused) {
    final weekday = now.weekday; // Dart's DateTime.weekday is ISO 1..7.
    final minuteOfDay = now.hour * 60 + now.minute;
    for (final rule in schedule.rules) {
      if (_ruleMatches(rule, weekday, minuteOfDay)) {
        final isBlock = rule.action == 'block';
        return EffectiveState(
          source: EffectiveSource.scheduleRule,
          outcome:
              isBlock ? EffectiveOutcome.blocked : EffectiveOutcome.filter,
          profileId: isBlock ? null : rule.profileId,
        );
      }
    }
  }

  // 3. Device Default.
  return EffectiveState(
    source: EffectiveSource.deviceDefault,
    outcome: EffectiveOutcome.filter,
    profileId: device.profileId,
  );
}

/// True when [rule] covers [weekday] (ISO 1..7) at [minuteOfDay] (0..1439).
///
/// A wrap-around window (e.g. 21:00–07:00, `endMinute < startMinute`) is owned
/// by the weekday it *starts* on: the rule's `weekdays` set lists the start
/// day, and the late-evening-through-next-morning span is matched as a single
/// window without splitting it across two weekday entries. This mirrors the
/// summary/editor model where a Bedtime rule on `[Mon..Sun]` with a wrapping
/// window covers each night.
bool _ruleMatches(RuleModel rule, int weekday, int minuteOfDay) {
  for (final w in rule.windows) {
    if (w.wrapsToNextDay) {
      // Split span: [start..1439] on the rule's weekday, plus the carry-over
      // [0..end) which belongs to the *next* day. Match either half, gating
      // the carry-over on the previous ISO day being in the weekday set.
      if (rule.weekdays.contains(weekday) && minuteOfDay >= w.startMinute) {
        return true;
      }
      final previousDay = weekday == 1 ? 7 : weekday - 1;
      if (rule.weekdays.contains(previousDay) && minuteOfDay < w.endMinute) {
        return true;
      }
    } else {
      if (rule.weekdays.contains(weekday) &&
          minuteOfDay >= w.startMinute &&
          minuteOfDay < w.endMinute) {
        return true;
      }
    }
  }
  return false;
}
