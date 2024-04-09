import 'package:collection/collection.dart';
import 'package:common/dragon/device/generator.dart';
import 'package:common/dragon/profile/controller.dart';

import '../../common/model.dart';
import '../../util/di.dart';
import 'api.dart';
import 'this_device.dart';

class DeviceController {
  late final _devices = dep<DeviceApi>();
  late final _thisDevice = dep<ThisDevice>();
  late final _nextAlias = dep<NameGenerator>();
  late final _profiles = dep<ProfileController>();

  List<JsonDevice> devices = [];

  JsonDevice? _selectedDevice;
  JsonProfile? _selectedProfile;

  Function onChange = () {};

  DeviceController() {
    // _userConfig.onChange.listen((_) => _updateProfileConfig());
    _profiles.onChange = () => onChange();
  }

  reload({bool createIfNeeded = false}) async {
    devices = await _devices.fetch();
    await _profiles.reload();

    if (!createIfNeeded) return;

    final d = await _thisDevice.fetch();

    final tag = d?.deviceTag;
    final alias = d?.alias ?? _nextAlias.get();
    final existing = devices.firstWhereOrNull((it) => it.deviceTag == tag);

    // A new device needs to be created
    if (tag == null || existing == null) {
      // Create a new profile for this device
      final p = await _profiles.addProfile("parent", "Parent", canReuse: true);

      // Create a new device with that profile
      final newDevice = await _devices.add(JsonDevicePayload.forCreate(
        alias: alias,
        profileId: p.profileId,
      ));

      _thisDevice.now = newDevice;
      // reload?
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
    _thisDevice.now = d;
  }

  _sendDeviceHeartbeat() async {}

  // selectDevice(DeviceTag tag) async {
  //   devices = await _devices.fetch();
  //   await _profiles.reload();
  //
  //   _selectedDevice = devices.firstWhereOrNull((it) => it.deviceTag == tag);
  //   if (_selectedDevice == null) throw Exception("Device $tag not found");
  //
  //   final pId = _selectedProfile?.profileId;
  //   _selectedProfile = _profiles.get(pId!);
  //
  //   final userConfig = UserFilterConfig(p.lists.toSet(), {
  //     FilterConfigKey.safeSearch: p.safeSearch,
  //   });
  //   _userConfig.now = userConfig;
  // }

  // _updateProfileConfig() async {
  //   final userConfig = _userConfig.now;
  //   if (userConfig == null) throw Exception("No user config");
  //
  //   final p = _selectedProfile;
  //   if (p == null) throw Exception("No profile selected");
  //
  //   final newProfile = p.copy(
  //     lists: userConfig.lists.toList(),
  //     safeSearch: userConfig.configs[FilterConfigKey.safeSearch] ?? false,
  //   );
  //
  //   //await _profiles.update(newProfile);
  // }

  Future<AddingDevice> addDevice(String alias, JsonProfile? profile) async {
    final p =
        profile ?? await _profiles.addProfile("child", "Child", canReuse: true);

    final d = await _devices.add(JsonDevicePayload.forCreate(
      alias: alias,
      profileId: p.profileId,
    ));

    devices.add(d);
    return AddingDevice(device: d, profile: p);
  }

  Future<JsonDevice> renameDevice(JsonDevice device, String alias) async {
    if (device.alias == alias) return device;
    if (!devices.any((it) => it.deviceTag == device.deviceTag)) {
      throw Exception("Device ${device.deviceTag} not found");
    }

    final d = await _devices.rename(device, alias);
    devices =
        devices.map((it) => it.deviceTag == d.deviceTag ? d : it).toList();
    onChange();
    return d;
  }

  changeDeviceProfile(JsonDevice device, JsonProfile profile) async {
    print("changing profile of ${device.deviceTag} to ${profile.alias}");
    final d = await _devices.changeProfile(device, profile.profileId);
    devices =
        devices.map((it) => it.deviceTag == device.deviceTag ? d : it).toList();
    _profiles.selectProfile(profile);
    onChange();
    return d;
  }

  deleteDevice(JsonDevice device) async {
    await _devices.delete(device);
    devices = devices.where((it) => it.deviceTag != device.deviceTag).toList();
  }

  pauseDevice(JsonDevice device, bool pause) async {
    final d = await _devices.pause(device, pause);
    devices =
        devices.map((it) => it.deviceTag == d.deviceTag ? d : it).toList();
    onChange();
    return d;
  }

  deleteProfile(JsonProfile profile) async {
    if (devices.any((it) => it.profileId == profile.profileId)) {
      throw Exception("Profile ${profile.profileId} is in use");
    }
    await _profiles.deleteProfile(profile);
    //onChange();
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
