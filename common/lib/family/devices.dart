import 'package:common/service/I18nService.dart';
import 'package:dartx/dartx.dart';

import 'package:collection/collection.dart';

import '../common/model.dart';

class FamilyDevices {
  final List<FamilyDevice> entries;
  final bool? hasDevices;
  bool hasThisDevice = false;

  FamilyDevices(this.entries, this.hasDevices) {
    hasThisDevice = entries.any((d) => d.thisDevice);
  }

  // Create the list from the persisted device names
  FamilyDevices fromNames(List<String> names, String thisDeviceName) {
    final devices = names
        .distinct()
        .map((name) => FamilyDevice(
              deviceName: name,
              deviceDisplayName:
                  _deviceDisplayName(name, name == thisDeviceName),
              stats: UiStats.empty(),
              thisDevice: name == thisDeviceName,
              enabled: true,
              configured: true,
            ))
        .toList();
    return FamilyDevices(devices, devices.isNotEmpty);
  }

  FamilyDevices fromStats(Map<String, UiStats> stats) {
    final devices = entries.map((d) {
      final s = stats[d.deviceName];
      if (s == null) return d;
      return FamilyDevice(
        deviceName: d.deviceName,
        deviceDisplayName: d.deviceDisplayName,
        stats: s,
        thisDevice: d.thisDevice,
        enabled: d.enabled,
        configured: d.configured,
      );
    }).toList();

    return FamilyDevices(devices, devices.isNotEmpty);
  }

  FamilyDevices addDevice(String name, UiStats stats) {
    final d = _findDeviceByName(name);
    if (d != null) throw Exception("Device $name already exists");

    final updated = entries;
    updated.add(FamilyDevice(
      deviceName: name,
      deviceDisplayName: name,
      stats: stats,
      thisDevice: false,
      enabled: true,
      configured: true,
    ));

    return FamilyDevices(updated, true);
  }

  FamilyDevices addThisDevice(String name, UiStats stats) {
    var d = _findThisDevice();
    if (d != null) throw Exception("This device already added");
    d = _findDeviceByName(name);
    if (d != null) throw Exception("Device $name already exists");

    final thisDevice = FamilyDevice(
      deviceName: name,
      deviceDisplayName: _deviceDisplayName(name, true),
      stats: stats,
      thisDevice: true,
      enabled: false,
      configured: false,
    );

    return FamilyDevices([thisDevice, ...entries], true);
  }

  _deviceDisplayName(String name, bool thisDevice) {
    if (thisDevice) {
      return "This device";
      return "family label this device".i18n.replaceFirst("%s", name);
    }
    return name;
  }

  FamilyDevices deleteDevice(String name) {
    final d = _findDeviceByName(name);
    if (d == null) throw Exception("Device $name does not exist");

    final updated = entries;
    updated.remove(d);

    return FamilyDevices(updated, updated.isNotEmpty);
  }

  FamilyDevices updateStats(String name, UiStats stats) {
    final d = _findDeviceByName(name);
    if (d == null) return this;

    final updated = entries;
    updated[entries.indexOf(d)] = FamilyDevice(
      deviceName: d.deviceName,
      deviceDisplayName: d.deviceDisplayName,
      stats: stats,
      thisDevice: d.thisDevice,
      enabled: d.enabled,
      configured: d.configured,
    );

    return FamilyDevices(updated, true);
  }

  FamilyDevices updateThisDeviceName(String newDeviceName) {
    final d = _findThisDevice();
    if (d == null) return this;

    final updated = entries;
    updated[entries.indexOf(d)] = FamilyDevice(
      deviceName: newDeviceName,
      deviceDisplayName: d.deviceDisplayName,
      stats: d.stats,
      thisDevice: true,
      enabled: d.enabled,
      configured: d.configured,
    );

    return FamilyDevices(updated, true);
  }

  bool hasDevice(String name, {bool thisDevice = false}) {
    final d = _findDeviceByName(name);
    if (d == null) return false;
    return d.thisDevice == thisDevice;
  }

  List<String> getNames() {
    return entries
        .map((d) => d.deviceName)
        .filter((d) => d.isNotEmpty)
        .toList();
  }

  _findDeviceByName(String name) {
    return IterableExtension(entries.where((e) => e.deviceName == name))
        .firstOrNull;
  }

  _findThisDevice() {
    return IterableExtension(entries.where((e) => e.thisDevice)).firstOrNull;
  }
}
