part of 'device.dart';

class ProfileInUseException implements Exception {
  ProfileInUseException();
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

    devices.add(d);
    onChange(true);
    return LinkingDevice(device: d, profile: p);
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

  changeDeviceProfile(JsonDevice device, JsonProfile profile, Marker m) async {
    log(m).i("changing profile of ${device.deviceTag} to ${profile.alias}");
    final draft = JsonDevice(
      deviceTag: device.deviceTag,
      alias: device.alias,
      profileId: profile.profileId,
      retention: device.retention,
      mode: device.mode,
    );
    final old = _commit(draft, dirty: true);

    try {
      final updated =
          await _devices.changeProfile(device, profile.profileId, m);
      _commit(updated);
      await _profiles.selectProfile(m, profile);
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

  changeDeviceMode(JsonDevice device, JsonDeviceMode mode, Marker m) async {
    final draft = JsonDevice(
      deviceTag: device.deviceTag,
      alias: device.alias,
      profileId: device.profileId,
      retention: device.retention,
      mode: mode,
    );
    final old = _commit(draft, dirty: true);

    try {
      final updated = await _devices.changeMode(device, mode, m);
      _commit(updated);
      return updated;
    } catch (e) {
      _commit(old);
      rethrow;
    }
  }

  deleteProfile(Marker m, JsonProfile profile) async {
    if (devices.any((it) => it.profileId == profile.profileId)) {
      throw ProfileInUseException();
    }
    await _profiles.deleteProfile(m, profile);
    //onChange();
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
