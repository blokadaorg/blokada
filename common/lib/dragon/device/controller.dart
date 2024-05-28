import 'package:collection/collection.dart';
import 'package:common/dragon/device/generator.dart';
import 'package:common/dragon/profile/controller.dart';

import '../../common/model.dart';
import '../../util/di.dart';
import 'api.dart';
import 'this_device.dart';

class ProfileInUseException implements Exception {
  ProfileInUseException();
}

class AlreadyLinkedException implements Exception {
  AlreadyLinkedException();
}

class DeviceController {
  late final _devices = dep<DeviceApi>();
  late final _thisDevice = dep<ThisDevice>();
  late final _nextAlias = dep<NameGenerator>();
  late final _profiles = dep<ProfileController>();

  List<JsonDevice> devices = [];

  JsonDevice? _selectedDevice;
  JsonProfile? _selectedProfile;

  Function onChange = (bool dirty) {};

  DeviceController() {
    // _userConfig.onChange.listen((_) => _updateProfileConfig());
    _profiles.onChange = () => onChange(false);
  }

  reload({bool createIfNeeded = false}) async {
    devices = await _devices.fetch();
    await _profiles.reload();

    if (!createIfNeeded) return;

    JsonDevice? d = await _thisDevice.fetch();
    if (devices.firstWhereOrNull((it) => it.deviceTag == d?.deviceTag) ==
        null) {
      // The value o _thisDevice is not correct for current account, reset
      _thisDevice.now = null;
      d = null;
    }

    final tag = d?.deviceTag;
    final alias = d?.alias ?? _nextAlias.get();
    final existing = devices.firstWhereOrNull((it) => it.deviceTag == tag);

    // A new device needs to be created
    if (tag == null || existing == null) {
      // Make sure we always have a child profile too on fresh install
      await _profiles.addProfile("child", "Child", canReuse: true);

      // Create a new profile for this device
      final p = await _profiles.addProfile("parent", "Parent", canReuse: true);

      // Create a new device with that profile
      final newDevice = await _devices.add(JsonDevicePayload.forCreate(
        alias: alias,
        profileId: p.profileId,
      ));

      _thisDevice.now = newDevice;
      devices = await _devices.fetch();
    }
  }

  JsonDevice getDevice(DeviceTag tag) {
    final d = devices.firstWhereOrNull((it) => it.deviceTag == tag);
    if (d == null) throw Exception("Device $tag not found");
    return d;
  }

  setThisDeviceForLinked(DeviceTag tag, String token) async {
    final devices = await _devices.fetchByToken(tag, token);
    final d = devices.firstWhereOrNull((it) => it.deviceTag == tag);
    if (d == null) throw Exception("Device $tag not found");

    if (_thisDevice.now?.deviceTag == tag) return;

    // If we were linked to another device, we cant change it now
    if (_thisDevice.now != null) {
      // If the linked device got deleted, allow to re-link
      final confirmedThisDevice = devices
          .firstWhereOrNull((it) => it.deviceTag == _thisDevice.now!.deviceTag);
      if (confirmedThisDevice != null) throw AlreadyLinkedException();
    }
    _thisDevice.now = d;
  }

  Future<LinkingDevice> addDevice(String alias, JsonProfile? profile) async {
    final p =
        profile ?? await _profiles.addProfile("child", "Child", canReuse: true);

    final d = await _devices.add(JsonDevicePayload.forCreate(
      alias: alias,
      profileId: p.profileId,
    ));

    devices.add(d);
    onChange(true);
    return LinkingDevice(device: d, profile: p);
  }

  Future<JsonDevice> renameDevice(JsonDevice device, String alias) async {
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
      final updated = await _devices.rename(device, alias);
      _commit(updated);
      return updated;
    } catch (e) {
      _commit(old);
      rethrow;
    }
  }

  changeDeviceProfile(JsonDevice device, JsonProfile profile) async {
    print("changing profile of ${device.deviceTag} to ${profile.alias}");
    final draft = JsonDevice(
      deviceTag: device.deviceTag,
      alias: device.alias,
      profileId: profile.profileId,
      retention: device.retention,
      mode: device.mode,
    );
    final old = _commit(draft, dirty: true);

    try {
      final updated = await _devices.changeProfile(device, profile.profileId);
      _commit(updated);
      _profiles.selectProfile(profile);
      return updated;
    } catch (e) {
      _commit(old);
      rethrow;
    }
  }

  deleteDevice(JsonDevice device) async {
    await _devices.delete(device);
    devices = devices.where((it) => it.deviceTag != device.deviceTag).toList();
    onChange(false);
  }

  pauseDevice(JsonDevice device, bool pause) async {
    final draft = JsonDevice(
      deviceTag: device.deviceTag,
      alias: device.alias,
      profileId: device.profileId,
      retention: device.retention,
      mode: pause ? JsonDeviceMode.off : JsonDeviceMode.on,
    );
    final old = _commit(draft, dirty: true);

    try {
      final updated = await _devices.pause(device, pause);
      _commit(updated);
      return updated;
    } catch (e) {
      _commit(old);
      rethrow;
    }
  }

  deleteProfile(JsonProfile profile) async {
    if (devices.any((it) => it.profileId == profile.profileId)) {
      throw ProfileInUseException();
    }
    await _profiles.deleteProfile(profile);
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

  startHeartbeatMonitoring(DeviceTag tag) {
    _heartbeatTag = tag;
    _monitorHeartbeat();
  }

  stopHeartbeatMonitoring() {
    _heartbeatTag = null;
  }

  _monitorHeartbeat() async {
    if (_heartbeatTag == null) return;
    devices = await _devices.fetch();
    final d = devices.firstWhereOrNull((it) => it.deviceTag == _heartbeatTag);
    if (d != null) {
      final last = DateTime.tryParse(d.lastHeartbeat);
      print("Monitoring heartbeat: found device $_heartbeatTag, last: $last");
      if (last != null &&
          last.isAfter(DateTime.now().subtract(const Duration(seconds: 10)))) {
        onHeartbeat(d.deviceTag);
        stopHeartbeatMonitoring();
        return;
      }
    }
    Future.delayed(const Duration(seconds: 10), _monitorHeartbeat);
  }
}
