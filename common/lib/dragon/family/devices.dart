import 'package:collection/collection.dart';
import 'package:dartx/dartx.dart';

import '../../common/model/model.dart';

class FamilyDevices {
  final List<FamilyDevice> entries;
  final bool? hasDevices;
  bool hasThisDevice = false;

  FamilyDevices(this.entries, this.hasDevices) {
    hasThisDevice = entries.any((d) => d.thisDevice);
  }

  // Create the list from the persisted device tags
  FamilyDevices fromApi(
    List<JsonDevice> devices,
    List<JsonProfile> profiles,
    DeviceTag? thisDeviceTag,
  ) {
    final dev = devices.map((it) => it.deviceTag).distinct().mapNotNull((tag) {
      final d = devices.firstOrNullWhere((d) => d.deviceTag == tag);
      if (d == null) return null;

      // TODO: maybe device without known profile should be handled
      final p = profiles.firstOrNullWhere((p) => p.profileId == d.profileId);
      if (p == null) return null;

      return FamilyDevice(
        device: d,
        profile: p,
        stats: UiStats.empty(), // Stats will be fetched a bit later
        thisDevice: d.deviceTag == thisDeviceTag,
        linked: true, // Any device loaded from persistence was linked before
      );
    }).toList();
    return FamilyDevices(dev, dev.isNotEmpty);
  }

  FamilyDevices updateStats(Map<DeviceTag, UiStats> stats) {
    final devices = entries.map((d) {
      final s = stats[d.device.deviceTag];
      if (s == null) return d;

      return FamilyDevice(
        device: d.device,
        profile: d.profile,
        stats: s,
        thisDevice: d.thisDevice,
        linked: d.linked,
      );
    }).toList();

    return FamilyDevices(devices, devices.isNotEmpty);
  }

  // FamilyDevices addDevice(JsonDevice device, UiStats stats) {
  //   final d = _findDeviceByTag(device.deviceTag);
  //   if (d != null) throw Exception("Device ${device.deviceTag} already exists");
  //
  //   final updated = entries;
  //   updated.add(FamilyDevice(
  //     device: d.device,
  //     profile: d.profile,
  //     stats: stats,
  //     thisDevice: d.thisDevice,
  //     linked: d.linked,
  //   ));
  //
  //   return FamilyDevices(updated, true);
  // }
  //
  // FamilyDevices addThisDevice(JsonDevice device, UiStats stats) {
  //   var d = _findThisDevice();
  //   if (d != null) throw Exception("This device already added");
  //
  //   d = _findDeviceByTag(device.deviceTag);
  //   if (d != null) throw Exception("Device ${device.deviceTag} already exists");
  //
  //   final thisDevice = FamilyDevice(
  //     device: d.device,
  //     profile: d.profile,
  //     stats: stats,
  //     thisDevice: d.thisDevice,
  //     linked: d.linked,
  //   );
  //
  //   return FamilyDevices([thisDevice, ...entries], true);
  // }

  // FamilyDevices deleteDevice(JsonDevice device) {
  //   final d = _findDeviceByTag(device.deviceTag);
  //   if (d == null) throw Exception("Device ${device.deviceTag} does not exist");
  //
  //   final updated = entries;
  //   updated.remove(d);
  //
  //   return FamilyDevices(updated, updated.isNotEmpty);
  // }

  bool hasDevice(DeviceTag tag, {bool thisDevice = false}) {
    final d = _findDeviceByTag(tag);
    if (d == null) return false;
    return d.thisDevice == thisDevice;
  }

  FamilyDevice getDevice(DeviceTag tag) {
    final d = _findDeviceByTag(tag);
    if (d == null) throw Exception("Device $tag not found");
    return d;
  }

  List<DeviceTag> getTags() {
    return entries
        .map((d) => d.device.deviceTag)
        .filter((d) => d.isNotEmpty)
        .toList();
  }

  _findDeviceByTag(DeviceTag tag) {
    return IterableExtension(entries.where((e) => e.device.deviceTag == tag))
        .firstOrNull;
  }

  _findThisDevice() {
    return IterableExtension(entries.where((e) => e.thisDevice)).firstOrNull;
  }
}
