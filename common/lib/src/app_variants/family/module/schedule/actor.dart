import 'package:collection/collection.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/schedule/platform_timezone.dart';
import 'package:common/src/app_variants/family/module/schedule/schedule.dart';
import 'package:common/src/core/core.dart';

/// Module entrypoint for device-attached schedules. Registered alongside
/// DeviceModule / ProfileModule from the family platform module so the
/// schedule actor is available wherever the device actor is.
class ScheduleModule with Module {
  @override
  onCreateModule() async {
    await register(ScheduleActor());
  }
}

/// Owns mutation + sync of a device's [ScheduleModel].
///
/// The pure transforms (`setPaused`, `addRule`, etc.) are exposed as static
/// methods so widget tests and the editor sheet can drive them without
/// spinning up the DI container. The instance method `saveSchedule` handles
/// the api round-trip and optimistic commit through [DeviceActor], including
/// populating `timezone` on first save per the coordinator plan's timezone
/// addendum.
class ScheduleActor with Logging, Actor {
  late final _devices = Core.get<DeviceActor>();
  late final _profiles = Core.get<ProfileActor>();

  /// Issued after any successful save so the device-detail UI rebuilds.
  Function onChange = () {};

  /// Returns the current canonical [ScheduleModel] for [deviceTag], or null
  /// if the device has no schedule attached yet (legacy or pre-first-save).
  ScheduleModel? scheduleFor(DeviceTag deviceTag) {
    final d = _devices.devices
        .firstWhereOrNull((it) => it.deviceTag == deviceTag);
    return d?.schedule;
  }

  /// Persist [schedule] for [device]. Validates locally against the current
  /// profile set so bad input surfaces as a UI error before the round-trip.
  ///
  /// On the device's first schedule save — meaning the device currently has
  /// no schedule attached (`device.schedule == null`) — resolves `timezone`
  /// from the platform's reported IANA zone, regardless of any backend
  /// default that may already sit on `device.timezone`. Subsequent saves
  /// preserve the existing `device.timezone` unless the caller explicitly
  /// overrides it. This keeps a legacy device whose backend record was
  /// populated with a default `UTC` from silently evaluating the parent's
  /// freshly-authored local-time rules in UTC.
  Future<JsonDevice> saveSchedule(
      JsonDevice device, ScheduleModel schedule, Marker m,
      {String? timezoneOverride}) async {
    return await log(m).trace('saveSchedule', (m) async {
      final profileIds = _profiles.profiles.map((p) => p.profileId).toSet();
      schedule.validate(profileIds: profileIds);

      final String tz;
      if (timezoneOverride != null) {
        tz = timezoneOverride;
      } else if (device.schedule == null) {
        tz = await platformTimezone();
      } else {
        tz = device.timezone ?? await platformTimezone();
      }
      final updated =
          await _devices.changeSchedule(device, schedule, tz, m);
      onChange();
      return updated;
    });
  }

  // --- pure transforms used by the rule-editor sheet + Schedule section ---

  static ScheduleModel setPaused(ScheduleModel s, bool paused) =>
      s.copyWith(paused: paused);

  static ScheduleModel addRule(ScheduleModel s, RuleModel rule) =>
      s.copyWith(rules: [...s.rules, rule]);

  static ScheduleModel updateRule(
      ScheduleModel s, int index, RuleModel rule) {
    final list = [...s.rules];
    list[index] = rule;
    return s.copyWith(rules: list);
  }

  static ScheduleModel deleteRule(ScheduleModel s, int index) {
    final list = [...s.rules]..removeAt(index);
    return s.copyWith(rules: list);
  }

  /// Reorder helper matching Flutter's `ReorderableListView.onReorder`
  /// semantics: when an item moves *down*, `newIndex` is one greater than
  /// the destination slot (because it's reported before removal). This
  /// helper mirrors the framework's documented behaviour by adjusting when
  /// oldIndex < newIndex.
  static ScheduleModel reorderRules(
      ScheduleModel s, int oldIndex, int newIndex) {
    final list = [...s.rules];
    final item = list.removeAt(oldIndex);
    final adjusted = oldIndex < newIndex ? newIndex - 1 : newIndex;
    list.insert(adjusted, item);
    return s.copyWith(rules: list);
  }
}
