part of 'family.dart';

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

  List<DeviceTag> getTags({
    ParentDeviceProtectionOwner parentDeviceOwner = ParentDeviceProtectionOwner.none,
  }) {
    return visibleEntries(parentDeviceOwner)
        .map((d) => d.device.deviceTag)
        .filter((d) => d.isNotEmpty)
        .toList();
  }

  /// Returns the rows Family should render on the parent home screen. When
  /// Blokada 6 owns this device, Family keeps child devices but suppresses its
  /// local "this device" row so it does not compete for DNS/VPN ownership.
  List<FamilyDevice> visibleEntries(ParentDeviceProtectionOwner parentDeviceOwner) {
    if (!parentDeviceOwner.isBlokada6) return entries;
    return entries.where((it) => !it.thisDevice).toList();
  }

  bool hasParentDevicePointer(ParentDeviceProtectionOwner parentDeviceOwner) {
    return parentDeviceOwner.isBlokada6;
  }

  bool hasVisibleDevices(ParentDeviceProtectionOwner parentDeviceOwner) {
    return visibleEntries(parentDeviceOwner).isNotEmpty ||
        hasParentDevicePointer(parentDeviceOwner);
  }

  int visibleCount(ParentDeviceProtectionOwner parentDeviceOwner) {
    return visibleEntries(parentDeviceOwner).length +
        (hasParentDevicePointer(parentDeviceOwner) ? 1 : 0);
  }

  _findDeviceByTag(DeviceTag tag) {
    return IterableExtension(entries.where((e) => e.device.deviceTag == tag)).firstOrNull;
  }

  @override
  String toString() {
    return 'FamilyDevices{entries: ${entries.length}, hasDevices: $hasDevices, hasThisDevice: $hasThisDevice}';
  }
}
