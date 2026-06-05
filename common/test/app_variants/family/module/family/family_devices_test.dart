import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FamilyDevices', () {
    test('hides this device when Blokada 6 owns parent protection', () {
      final devices = _devicesWithParentAndChild();

      final visible = devices.visibleEntries(ParentDeviceProtectionOwner.blokada6);

      expect(visible.map((it) => it.device.deviceTag), ['child-device']);
      expect(
        devices.hasVisibleDevices(ParentDeviceProtectionOwner.blokada6),
        true,
      );
      expect(devices.visibleCount(ParentDeviceProtectionOwner.blokada6), 2);
      expect(
        devices.getTags(parentDeviceOwner: ParentDeviceProtectionOwner.blokada6),
        ['child-device'],
      );
    });

    test('keeps this device for normal Family protection', () {
      final devices = _devicesWithParentAndChild();

      final visible = devices.visibleEntries(ParentDeviceProtectionOwner.none);

      expect(
        visible.map((it) => it.device.deviceTag),
        ['parent-device', 'child-device'],
      );
      expect(devices.visibleCount(ParentDeviceProtectionOwner.none), 2);
    });

    test('maps the backend dns flavor to a protection owner', () {
      expect(
        parentDeviceProtectionOwnerFromDnsFlavor('cloud'),
        ParentDeviceProtectionOwner.blokada6,
      );
      expect(
        parentDeviceProtectionOwnerFromDnsFlavor('plus'),
        ParentDeviceProtectionOwner.blokada6,
      );
      // Family's own DNS (and an absent or unexpected flavor) means Family
      // should proceed normally, not defer to Blokada 6.
      expect(
        parentDeviceProtectionOwnerFromDnsFlavor('family'),
        ParentDeviceProtectionOwner.none,
      );
      expect(
        parentDeviceProtectionOwnerFromDnsFlavor(null),
        ParentDeviceProtectionOwner.none,
      );
      expect(
        parentDeviceProtectionOwnerFromDnsFlavor('unexpected'),
        ParentDeviceProtectionOwner.none,
      );
    });
  });
}

FamilyDevices _devicesWithParentAndChild() {
  return FamilyDevices([], null).fromApi(
    [
      _device('parent-device', 'Parent phone', 'parent-profile'),
      _device('child-device', 'Child phone', 'child-profile'),
    ],
    [
      _profile('parent-profile', 'Parent'),
      _profile('child-profile', 'Child'),
    ],
    'parent-device',
  );
}

JsonDevice _device(String tag, String alias, String profileId) {
  return JsonDevice(
    deviceTag: tag,
    alias: alias,
    mode: JsonDeviceMode.on,
    retention: '24h',
    profileId: profileId,
  );
}

JsonProfile _profile(String id, String alias) {
  return JsonProfile(
    profileId: id,
    alias: alias,
    lists: const [],
    safeSearch: false,
  );
}
