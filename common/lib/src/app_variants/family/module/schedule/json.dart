part of 'schedule.dart';

/// One contiguous time interval within a single 24h day, expressed in
/// minutes-past-midnight in the device's local clock. `endMinute < startMinute`
/// means the window wraps into the next calendar day (e.g. Bedtime
/// 21:00-07:00 → start=1260, end=420). `endMinute == startMinute` is invalid
/// and rejected by the api; we mirror that in [ScheduleModel.validate].
class TimeWindowModel {
  final int startMinute;
  final int endMinute;

  const TimeWindowModel({required this.startMinute, required this.endMinute});

  bool get wrapsToNextDay => endMinute < startMinute;

  factory TimeWindowModel.fromJson(Map<String, dynamic> json) {
    try {
      return TimeWindowModel(
        startMinute: json['start_minute'] as int,
        endMinute: json['end_minute'] as int,
      );
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() => {
        'start_minute': startMinute,
        'end_minute': endMinute,
      };

  /// Editor convenience: copy with a new start minute, preserving end.
  TimeWindowModel copyWithStart(int v) =>
      TimeWindowModel(startMinute: v, endMinute: endMinute);

  /// Editor convenience: copy with a new end minute, preserving start.
  TimeWindowModel copyWithEnd(int v) =>
      TimeWindowModel(startMinute: startMinute, endMinute: v);
}

/// Raised by [ScheduleModel.validate] when a schedule violates a wire-format
/// constraint. [code] is the stable identifier shared with the api's
/// 400-rejection table — keeping them in sync means a server response can be
/// mapped back to the same UI message without an extra translation table.
class ScheduleValidationError implements Exception {
  final String code;
  final String message;
  ScheduleValidationError(this.code, this.message);

  @override
  String toString() => 'ScheduleValidationError($code): $message';
}

/// A single rule entry inside a [ScheduleModel]. List order is significant
/// (first match wins, evaluated by the resolver). [weekdays] uses ISO 1..7
/// (Mon..Sun) and is canonicalised sorted-ascending on construction so the
/// wire-format payload is deterministic. [windows] order is presentational,
/// not semantic, but is preserved on round-trip.
class RuleModel {
  final String profileId;
  final List<int> weekdays;
  final List<TimeWindowModel> windows;

  /// What the rule does while active. Mirrors the api/blockarust wire key
  /// `"action"`: lowercase `"filter"` (apply [profileId]) or `"block"` (drop
  /// all queries; [profileId] is empty). Null/absent is treated as `"filter"`
  /// so legacy rules behave unchanged. Kept on the wire only when non-null —
  /// `toJson` omits the key for filter/null so the payload stays minimal and
  /// matches the api's "absent ⇒ filter" convention.
  final String? action;

  RuleModel({
    required this.profileId,
    required List<int> weekdays,
    required this.windows,
    this.action,
  }) : weekdays = List<int>.unmodifiable([...weekdays]..sort());

  factory RuleModel.fromJson(Map<String, dynamic> json) {
    try {
      return RuleModel(
        profileId: json['profile_id'] as String,
        weekdays: List<int>.from(json['weekdays'] as List<dynamic>),
        windows: (json['windows'] as List<dynamic>)
            .map((e) => TimeWindowModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        action: json['action'] as String?,
      );
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'weekdays': weekdays,
        'windows': windows.map((w) => w.toJson()).toList(),
        // Omit `action` for filter/null: the api treats an absent key as
        // filter, so emitting it would be redundant and diverge from the
        // wire convention shared with blockarust.
        if (action != null) 'action': action,
      };

  RuleModel copyWith({
    String? profileId,
    List<int>? weekdays,
    List<TimeWindowModel>? windows,
    String? action,
  }) =>
      RuleModel(
        profileId: profileId ?? this.profileId,
        weekdays: weekdays ?? this.weekdays,
        windows: windows ?? this.windows,
        action: action ?? this.action,
      );
}

/// Mirror of the api's `schedule` field on a Family device.
///
/// Field tags map 1:1 to the wire format locked in the coordinator plan;
/// do not change them. Per the 2026-05-15 amendment the wire format has no
/// `default_profile_id`: the device's existing top-level `profile_id` is the
/// Default. [paused] gates rule evaluation entirely — when true the resolver
/// returns the device's Default profile regardless of clock or rules.
class ScheduleModel {
  final bool paused;
  final List<RuleModel> rules;

  const ScheduleModel({required this.paused, required this.rules});

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    try {
      return ScheduleModel(
        paused: (json['paused'] as bool?) ?? false,
        rules: ((json['rules'] as List<dynamic>?) ?? const [])
            .map((e) => RuleModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() => {
        'paused': paused,
        'rules': rules.map((r) => r.toJson()).toList(),
      };

  ScheduleModel copyWith({bool? paused, List<RuleModel>? rules}) =>
      ScheduleModel(
        paused: paused ?? this.paused,
        rules: rules ?? this.rules,
      );

  /// Client-side mirror of the api's 400-rejection rules. Throws on the
  /// first violation. Call sites: [ScheduleActor] before PUT, and the
  /// rule-editor sheet's Save before close. [profileIds] is the current
  /// account profile set, so unknown ids surface as a UI error rather than
  /// a server round-trip.
  void validate({required Set<String> profileIds}) {
    for (final rule in rules) {
      if (rule.weekdays.isEmpty) {
        throw ScheduleValidationError(
            'empty_weekdays', 'A rule must apply to at least one day.');
      }
      for (final day in rule.weekdays) {
        if (day < 1 || day > 7) {
          throw ScheduleValidationError(
              'invalid_weekday', 'Weekday $day is not in 1..7.');
        }
      }
      if (rule.windows.isEmpty) {
        throw ScheduleValidationError(
            'empty_windows', 'A rule must have at least one time window.');
      }
      if (rule.windows.length > 4) {
        throw ScheduleValidationError('too_many_windows',
            'A rule cannot have more than 4 time windows.');
      }
      for (final w in rule.windows) {
        if (w.startMinute == w.endMinute) {
          throw ScheduleValidationError('zero_length_window',
              'A time window cannot have equal start and end minutes.');
        }
        if (w.startMinute < 0 ||
            w.startMinute > 1439 ||
            w.endMinute < 0 ||
            w.endMinute > 1439) {
          throw ScheduleValidationError(
              'invalid_minute', 'Window minutes must be in 0..1439.');
        }
      }
      // Action / profile mutual exclusion, mirroring the api's 400 table:
      // a `block` rule drops all queries and must carry no profile; a
      // `filter` rule (the default when `action` is null/absent) applies a
      // profile and must name a known one. Any other action string is a
      // wire-format violation we reject before the round-trip.
      final action = rule.action;
      if (action != null && action != 'filter' && action != 'block') {
        throw ScheduleValidationError('invalid_rule_action',
            'Rule action "$action" must be "filter" or "block".');
      }
      if (action == 'block') {
        if (rule.profileId.isNotEmpty) {
          throw ScheduleValidationError('block_rule_with_profile',
              'A block rule must not carry a profile_id.');
        }
        // A block rule needs no profile reference; skip the profile-set check.
        continue;
      }
      if (rule.profileId.isEmpty) {
        throw ScheduleValidationError('filter_rule_without_profile',
            'A filter rule must carry a profile_id.');
      }
      if (!profileIds.contains(rule.profileId)) {
        throw ScheduleValidationError('unknown_rule_profile',
            'Rule profile ${rule.profileId} is not on this account.');
      }
    }
  }
}
