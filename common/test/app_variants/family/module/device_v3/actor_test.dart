import 'dart:async';

import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tools.dart';

JsonDevice _device({
  String tag = 'device-1',
  String alias = 'Kid phone',
  String profileId = 'profile-default',
  JsonDeviceMode mode = JsonDeviceMode.blocked,
  DateTime? modeUntil,
}) =>
    JsonDevice(
      deviceTag: tag,
      alias: alias,
      mode: mode,
      modeUntil: modeUntil,
      retention: '24h',
      profileId: profileId,
    );

JsonProfile _profile(String id) => JsonProfile(
      profileId: id,
      alias: 'Custom ()',
      lists: const [],
      safeSearch: false,
    );

/// Keeps API calls pending so tests can inspect DeviceActor's optimistic cache
/// before the canonical response reconciles it.
class _HoldingDeviceApi extends DeviceApi {
  final renameCompleter = Completer<JsonDevice>();
  final changeProfileCompleter = Completer<JsonDevice>();

  @override
  Future<JsonDevice> rename(JsonDevice device, String newName, Marker m) {
    return renameCompleter.future;
  }

  @override
  Future<JsonDevice> changeProfile(JsonDevice device, String profileId, Marker m) {
    return changeProfileCompleter.future;
  }
}

void main() {
  group('DeviceActor optimistic drafts', () {
    test('renameDevice preserves a bounded override expiry while saving', () async {
      await withTrace((m) async {
        final until = DateTime.utc(2026, 6, 8, 21);
        final original = _device(modeUntil: until);
        final api = _HoldingDeviceApi();
        final actor = DeviceActor()..devices = [original];

        Core.register<DeviceApi>(api);
        Core.register<ThisDevice>(ThisDevice());

        final pending = actor.renameDevice(original, 'Renamed kid phone', m);

        expect(actor.devices.single.alias, 'Renamed kid phone');
        expect(actor.devices.single.modeUntil, until);

        api.renameCompleter.complete(
          _device(alias: 'Renamed kid phone', modeUntil: until),
        );
        await pending;
      });
    });

    test('changeDeviceProfile preserves a bounded override expiry while saving', () async {
      await withTrace((m) async {
        final until = DateTime.utc(2026, 6, 8, 21);
        final original = _device(modeUntil: until);
        final nextProfile = _profile('profile-next');
        final api = _HoldingDeviceApi();
        final actor = DeviceActor()..devices = [original];

        Core.register<DeviceApi>(api);

        final pending = actor.changeDeviceProfile(
          original,
          nextProfile,
          m,
          select: false,
        );

        expect(actor.devices.single.profileId, 'profile-next');
        expect(actor.devices.single.modeUntil, until);

        api.changeProfileCompleter.complete(
          _device(profileId: 'profile-next', modeUntil: until),
        );
        await pending;
      });
    });
  });
}
