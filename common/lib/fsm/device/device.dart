import 'package:dartx/dartx.dart';
import 'package:vistraced/annotations.dart';

import '../machine.dart';
import '../profile/json.dart';
import '../profile/profile.dart';
import 'json.dart';

part 'device.g.dart';

typedef DeviceTag = String;
typedef DeviceAlias = String;

@context
mixin DeviceContext on Context<DeviceContext> {
  List<JsonDevice>? devices;
  JsonDevice? selected;
  JsonDevice? thisDevice;

  // @action
  late Action<void, JsonDevice?> _actionPersistedDevice;
  late Action<JsonDevice, void> _actionSavePersistedDevice;
  late Action<void, List<JsonDevice>> _actionDevices;
  late Action<JsonProfilePayload, ProfileId> _actionCreateProfile;
  late Action<JsonDevicePayload, JsonDevice> _actionCreateDevice;
  late Action<void, DeviceAlias> _actionGenerateDeviceAlias;
}

@States(DeviceContext)
mixin DeviceStates {
  @initialState
  static reload(DeviceContext c) async {
    c.devices = await c._actionDevices(null);
    return thisDevice;
  }

  @fatalState
  static fatal(DeviceContext c) async {}

  static thisDevice(DeviceContext c) async {
    final d = await c._actionPersistedDevice(null);
    final tag = d?.deviceTag;
    final alias = d?.alias ?? await c._actionGenerateDeviceAlias(null);
    final existing = c.devices?.firstOrNullWhere((it) => it.deviceTag == tag);

    // A new device needs to be created
    if (tag == null || existing == null) {
      // Create a new profile for this device
      final profileId =
          await c._actionCreateProfile(JsonProfilePayload.forCreate(
        alias: alias,
      ));

      // Create a new device with that profile
      final device = await c._actionCreateDevice(JsonDevicePayload.forCreate(
        alias: alias,
        profileId: profileId,
      ));
      await c._actionSavePersistedDevice(device);

      return reload;
    }

    return ready;
  }

  static ready(DeviceContext c) async {}

  static onSelectDevice(DeviceContext c, DeviceTag tag) async {
    c.guard([ready]);

    c.selected = c.devices?.firstOrNullWhere((it) => it.deviceTag == tag);
    if (c.selected == null) {
      throw Exception("Device $tag not found");
    }
    return deviceSelected;
  }

  static deviceSelected(DeviceContext c) async {}
}
