part of 'device.dart';

/// Why a profile cannot be deleted yet.
///
/// `deviceDefault` — at least one device's top-level `profileId` points
/// at it (the device's Default). `ruleTarget` — at least one schedule
/// rule (possibly on another device, since profiles are account-global)
/// points at it. UI surfaces a different message per reason so the
/// parent knows exactly what to fix first.
enum ProfileInUseReason { deviceDefault, ruleTarget }

class ProfileInUseException implements Exception {
  final ProfileInUseReason reason;
  /// Devices whose record blocks this delete (default-profile match for
  /// [ProfileInUseReason.deviceDefault]; rule-target match for
  /// [ProfileInUseReason.ruleTarget]). Captured at throw time so the UI
  /// can name them without a second lookup against a possibly-changed
  /// devices list.
  final List<JsonDevice> affectedDevices;
  ProfileInUseException({
    required this.reason,
    this.affectedDevices = const [],
  });
}

class AlreadyLinkedException implements Exception {
  AlreadyLinkedException();
}

class DeviceActor with Logging, Actor {
  late final _devices = Core.get<DeviceApi>();
  late final _thisDevice = Core.get<ThisDevice>();
  late final _nextAlias = Core.get<NameGenerator>();
  late final _profiles = Core.get<ProfileActor>();

  List<JsonDevice> devices = [];

  Function onChange = (bool dirty) {};

  @override
  onStart(Marker m) async {
    // _userConfig.onChange.listen((_) => _updateProfileConfig());
    _profiles.onChange = () => onChange(false);
  }

  reload(Marker m, {bool createIfNeeded = false}) async {
    devices = await _devices.fetch(m);
    await _profiles.reload(m);

    if (!createIfNeeded) return;

    JsonDevice? d = await _thisDevice.fetch(m);
    if (devices.firstWhereOrNull((it) => it.deviceTag == d?.deviceTag) ==
        null) {
      // The value o _thisDevice is not correct for current account, reset
      await _thisDevice.change(m, null);
      d = null;
    }

    final tag = d?.deviceTag;
    final alias = d?.alias ?? _nextAlias.get();
    final existing = devices.firstWhereOrNull((it) => it.deviceTag == tag);

    // A new device needs to be created
    if (tag == null || existing == null) {
      // Make sure we always have a child profile too on fresh install
      await _profiles.addProfile("child", "Child", m, canReuse: true);

      // Create a new profile for this device
      final p =
          await _profiles.addProfile("parent", "Parent", m, canReuse: true);

      // Create a new device with that profile
      final newDevice = await _devices.add(
          JsonDevicePayload.forCreate(
            alias: alias,
            profileId: p.profileId,
          ),
          m);

      await _thisDevice.change(m, newDevice);
      devices = await _devices.fetch(m);
    }
  }

  /// Seed a kid device with the two template profiles (School + Bedtime) and
  /// the locked seeded schedule (Mon-Fri 08:00-15:00 and every day
  /// 21:00-07:00). The schedule lives on the kid device whose base profile
  /// the parent is restricting, not on the parent's own controller device,
  /// so this is invoked by [seedScheduleForLinkedDevice] from the link
  /// completion path rather than from [reload]'s controller-device creation.
  ///
  /// Deferred to post-link rather than running inside [addDevice] so the
  /// School/Bedtime profile creation does not leak into the parent's profile
  /// picker if the parent cancels the QR/link flow before the kid device
  /// accepts.
  ///
  /// Per-device behavior: every linked kid device gets seeded. The two
  /// template profiles are reused across calls via `canReuse: true`, so a
  /// second kid device's seed shares the same School/Bedtime entries as the
  /// first.
  ///
  /// Returns the updated [JsonDevice] carrying the persisted schedule so the
  /// caller can publish the seeded record (and not the pre-seed POST result
  /// with `schedule == null`) into the local cache. Per the coordinator
  /// plan's timezone addendum, this is the device's first schedule write —
  /// populate `timezone` from the platform's reported IANA identifier
  /// (resolved via the shared `platformTimezone` channel, same as the
  /// interactive save path) so the resolver can compute DST correctly
  /// without depending on a later refresh from the app. Resolving the IANA id
  /// here is required: `DateTime.now().timeZoneName` yields an abbreviation
  /// ("CEST") which the api rejects with a 400.
  Future<JsonDevice> _seedScheduleForNewDevice(
      JsonDevice device, Marker m) async {
    final school =
        await _profiles.addProfile("", "School", m, canReuse: true);
    final bedtime =
        await _profiles.addProfile("", "Bedtime", m, canReuse: true);
    final schedule = buildSeededSchedule(
      schoolProfileId: school.profileId,
      bedtimeProfileId: bedtime.profileId,
    );
    return await _devices.changeSchedule(
        device, schedule, await platformTimezone(), m);
  }

  JsonDevice getDevice(DeviceTag tag) {
    final d = devices.firstWhereOrNull((it) => it.deviceTag == tag);
    if (d == null) throw Exception("Device $tag not found");
    return d;
  }

  setThisDeviceForLinked(DeviceTag tag, String token, Marker m) async {
    final devices = await _devices.fetchByToken(tag, token, m);
    final d = devices.firstWhereOrNull((it) => it.deviceTag == tag);
    if (d == null) throw Exception("Device $tag not found");

    final thisDevice = await _thisDevice.now();
    if (thisDevice?.deviceTag == tag) return;

    // If we were linked to another device, we cant change it now
    if (thisDevice != null) {
      // If the linked device got deleted, allow to re-link
      final confirmedThisDevice = devices
          .firstWhereOrNull((it) => it.deviceTag == thisDevice.deviceTag);
      if (confirmedThisDevice != null) throw AlreadyLinkedException();
    }
    await _thisDevice.change(m, d);
  }

  Future<LinkingDevice> addDevice(
      String alias, JsonProfile? profile, Marker m) async {
    final p = profile ??
        await _profiles.addProfile("child", "Child", m, canReuse: true);

    final d = await _devices.add(
        JsonDevicePayload.forCreate(
          alias: alias,
          profileId: p.profileId,
        ),
        m);

    // Note: the schedule seed (School/Bedtime profiles + locked schedule) is
    // intentionally NOT run here. It runs from `LinkActor._finishLinkDevice`
    // once the kid device has actually accepted the link, so a parent who
    // cancels mid-link never persists the seeded profiles or schedule.
    devices.add(d);
    onChange(true);
    return LinkingDevice(device: d, profile: p);
  }

  /// Seed the just-linked kid [device] with the School + Bedtime templates
  /// and the locked schedule, then publish the updated record into the local
  /// cache. Called by `LinkActor._finishLinkDevice` after a successful link,
  /// not from [addDevice], so cancelled link flows do not leak the seeded
  /// profiles into the parent's profile picker.
  ///
  /// Skips devices that already carry a schedule. The link sheet's relink
  /// path reuses an existing device, and overwriting its customised rules
  /// with the locked seed would silently erase the parent's configuration.
  /// Keying the guard on `device.schedule != null` (rather than the
  /// transient `LinkingDevice.relink` flag) also covers any future path
  /// that hands a previously-configured device through this entry point.
  ///
  /// Best-effort: the device record is already published from [addDevice], so
  /// a seed failure here just leaves the device with `schedule == null`. The
  /// parent can configure the schedule from the device's Schedule section.
  Future<void> seedScheduleForLinkedDevice(
      JsonDevice device, Marker m) async {
    if (device.schedule != null) return;

    JsonDevice? seeded;
    try {
      seeded = await _seedScheduleForNewDevice(device, m);
    } catch (e, st) {
      log(m).e(
          msg: "seedScheduleForLinkedDevice failed for ${device.deviceTag}: "
              "$e\n$st");
      return;
    }
    final i = devices.indexWhere((it) => it.deviceTag == device.deviceTag);
    if (i >= 0) {
      devices[i] = seeded;
      onChange(true);
    }
  }

  Future<JsonDevice> renameDevice(
      JsonDevice device, String alias, Marker m) async {
    if (device.alias == alias) return device;
    if (!devices.any((it) => it.deviceTag == device.deviceTag)) {
      throw Exception("Device ${device.deviceTag} not found");
    }

    final draft = JsonDevice(
      deviceTag: device.deviceTag,
      alias: alias,
      profileId: device.profileId,
      retention: device.retention,
      mode: device.mode,
      modeUntil: device.modeUntil,
      schedule: device.schedule,
      timezone: device.timezone,
    );
    final old = _commit(draft, dirty: true);

    try {
      final updated = await _devices.rename(device, alias, m);

      // Also update thisDevice if it was renamed
      if (_thisDevice.present?.deviceTag == device.deviceTag) {
        await _thisDevice.change(m, updated);
      }

      _commit(updated);
      return updated;
    } catch (e) {
      _commit(old);
      rethrow;
    }
  }

  // [select] also makes [profile] the currently selected one, rewriting this
  // device's own filter config. That is wrong while linking a child device, so
  // the link flow passes select: false to only post the device's new profile.
  Future<JsonDevice> changeDeviceProfile(
      JsonDevice device, JsonProfile profile, Marker m,
      {bool select = true}) async {
    log(m).i("changing profile of ${device.deviceTag} to ${profile.alias}");
    final draft = JsonDevice(
      deviceTag: device.deviceTag,
      alias: device.alias,
      profileId: profile.profileId,
      retention: device.retention,
      mode: device.mode,
      modeUntil: device.modeUntil,
      schedule: device.schedule,
      timezone: device.timezone,
    );
    final old = _commit(draft, dirty: true);

    try {
      final updated =
          await _devices.changeProfile(device, profile.profileId, m);
      _commit(updated);
      if (select) await _profiles.selectProfile(m, profile);
      return updated;
    } catch (e) {
      _commit(old);
      rethrow;
    }
  }

  deleteDevice(JsonDevice device, Marker m) async {
    await _devices.delete(device, m);
    devices = devices.where((it) => it.deviceTag != device.deviceTag).toList();
    onChange(false);
  }

  /// Change a device's released [mode]. [modeUntil] is optional and defaults
  /// to null, reproducing today's indefinite override; when supplied it bounds
  /// the override to that instant (after which the device reverts to its
  /// schedule/default server-side). The optimistic draft carries the same
  /// bound so the UI reflects it before the round-trip.
  changeDeviceMode(JsonDevice device, JsonDeviceMode mode, Marker m,
      {DateTime? modeUntil}) async {
    final draft = JsonDevice(
      deviceTag: device.deviceTag,
      alias: device.alias,
      profileId: device.profileId,
      retention: device.retention,
      mode: mode,
      modeUntil: modeUntil,
      schedule: device.schedule,
      timezone: device.timezone,
    );
    final old = _commit(draft, dirty: true);

    try {
      final updated =
          await _devices.changeMode(device, mode, m, modeUntil: modeUntil);
      _commit(updated);
      return updated;
    } catch (e) {
      _commit(old);
      rethrow;
    }
  }

  /// Clear any active override and hand the device back to its schedule /
  /// default: sets `mode = on` and drops `mode_until` (passing null bounds is
  /// what tells the api to resume indefinite normal evaluation). Thin wrapper
  /// over [changeDeviceMode] kept as a named helper so call sites read as
  /// "resume" rather than an opaque `on` + null.
  Future<JsonDevice> resumeDevice(JsonDevice device, Marker m) async {
    return await changeDeviceMode(device, JsonDeviceMode.on, m,
        modeUntil: null);
  }

  /// Optimistically commit a new [schedule] (and optional [timezone]) for
  /// [device], hit the api, and reconcile with the canonical response. On
  /// failure the previous device record is restored so the UI doesn't show
  /// a phantom change.
  Future<JsonDevice> changeSchedule(JsonDevice device, ScheduleModel schedule,
      String? timezone, Marker m) async {
    final draft = JsonDevice(
      deviceTag: device.deviceTag,
      alias: device.alias,
      profileId: device.profileId,
      retention: device.retention,
      mode: device.mode,
      // Carry the override expiry too: a schedule edit must not optimistically
      // drop `modeUntil` (which would flip a bounded override to "indefinite"
      // in the Now readout until the api response reconciles).
      modeUntil: device.modeUntil,
      schedule: schedule,
      timezone: timezone ?? device.timezone,
    );
    final old = _commit(draft, dirty: true);

    try {
      final updated = await _devices.changeSchedule(device, schedule, timezone, m);
      _commit(updated);
      return updated;
    } catch (e) {
      _commit(old);
      rethrow;
    }
  }

  deleteProfile(Marker m, JsonProfile profile) async {
    final blocker = checkProfileDeletable(devices, profile);
    if (blocker != null) throw blocker;
    await _profiles.deleteProfile(m, profile);
    //onChange();
  }

  /// Pure guard used by [deleteProfile]. Returns `null` when [profile] is
  /// safe to delete, or the [ProfileInUseException] the actor should
  /// throw otherwise. Profiles are account-global, so this checks every
  /// known device for both `profileId` (device default) and schedule
  /// rule references; either kind of orphan blocks the delete. Device
  /// default wins when a device both defaults to AND rule-targets the
  /// profile — the parent has to change the default first either way.
  /// Exposed as a static so the guard can be exercised without
  /// bootstrapping the DI container.
  static ProfileInUseException? checkProfileDeletable(
      List<JsonDevice> devices, JsonProfile profile) {
    final defaults = devices
        .where((d) => d.profileId == profile.profileId)
        .toList();
    if (defaults.isNotEmpty) {
      return ProfileInUseException(
          reason: ProfileInUseReason.deviceDefault,
          affectedDevices: defaults);
    }
    final ruleTargets = devices
        .where((d) =>
            d.schedule?.rules.any((r) => r.profileId == profile.profileId) ??
            false)
        .toList();
    if (ruleTargets.isNotEmpty) {
      return ProfileInUseException(
          reason: ProfileInUseReason.ruleTarget,
          affectedDevices: ruleTargets);
    }
    return null;
  }

  JsonDevice _commit(JsonDevice device, {bool dirty = false}) {
    final old = devices.firstWhere((it) => it.deviceTag == device.deviceTag);
    devices = devices
        .map((it) => it.deviceTag == device.deviceTag ? device : it)
        .toList();
    onChange(dirty);
    return old;
  }

  // A callback when a heartbeat for deviceTag is discovered.
  // Used by parent to know when device got properly added.
  Function(DeviceTag) onHeartbeat = (tag) {};

  DeviceTag? _heartbeatTag;

  startHeartbeatMonitoring(DeviceTag tag, Marker m) {
    _heartbeatTag = tag;
    _monitorHeartbeat(m);
  }

  stopHeartbeatMonitoring() {
    _heartbeatTag = null;
  }

  _monitorHeartbeat(Marker m) async {
    if (_heartbeatTag == null) return;
    devices = await _devices.fetch(m);
    final d = devices.firstWhereOrNull((it) => it.deviceTag == _heartbeatTag);
    if (d != null) {
      final last = DateTime.tryParse(d.lastHeartbeat);
      log(m)
          .i("Monitoring heartbeat: found device $_heartbeatTag, last: $last");
      if (last != null &&
          last.isAfter(DateTime.now().subtract(const Duration(seconds: 10)))) {
        onHeartbeat(d.deviceTag);
        stopHeartbeatMonitoring();
        return;
      }
    }
    Future.delayed(
        const Duration(seconds: 10), () => _monitorHeartbeat(Markers.device));
  }
}
