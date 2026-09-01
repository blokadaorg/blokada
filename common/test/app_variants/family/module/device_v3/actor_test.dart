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
    )
      // late field, only assigned by fromJson. Persisting calls toJson, so a
      // constructor-built fixture needs it set explicitly.
      ..lastHeartbeat = '2026-01-01T00:00:00Z';

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
  group('DeviceActor.setThisDeviceForLinked re-home guard', () {
    test('refuses an unconfirmed re-home onto a different account', () async {
      await withTrace((m) async {
        Core.register<DeviceApi>(_ListingDeviceApi([_device(tag: 'attacker-tag')]));

        Core.register<Persistence>(Persistence(isSecure: false));
        final thisDevice = ThisDevice();
        Core.register<ThisDevice>(thisDevice);
        // This device already belongs to another family account. That tag is
        // absent from the incoming account's list, which is exactly the case
        // the old guard could not see.
        await thisDevice.change(m, _device(tag: 'victim-tag'));

        final actor = DeviceActor();

        await expectLater(
          actor.setThisDeviceForLinked('attacker-tag', 'token', m),
          throwsA(isA<AlreadyLinkedException>()),
        );

        final after = await thisDevice.fetch(m);
        expect(after?.deviceTag, 'victim-tag');
      });
    });

    test('allows a confirmed re-home', () async {
      await withTrace((m) async {
        Core.register<DeviceApi>(_ListingDeviceApi([_device(tag: 'new-tag')]));

        Core.register<Persistence>(Persistence(isSecure: false));
        final thisDevice = ThisDevice();
        Core.register<ThisDevice>(thisDevice);
        await thisDevice.change(m, _device(tag: 'old-tag'));

        final actor = DeviceActor();
        await actor.setThisDeviceForLinked('new-tag', 'token', m, confirmed: true);

        final after = await thisDevice.fetch(m);
        expect(after?.deviceTag, 'new-tag');
      });
    });

    test('is idempotent for the tag already persisted', () async {
      await withTrace((m) async {
        final same = _device(tag: 'same-tag');
        Core.register<DeviceApi>(_ListingDeviceApi([same]));

        Core.register<Persistence>(Persistence(isSecure: false));
        final thisDevice = ThisDevice();
        Core.register<ThisDevice>(thisDevice);
        await thisDevice.change(m, same);

        final actor = DeviceActor();
        await actor.setThisDeviceForLinked('same-tag', 'token', m);

        final after = await thisDevice.fetch(m);
        expect(after?.deviceTag, 'same-tag');
      });
    });

    test('links a fresh device with no confirmation', () async {
      await withTrace((m) async {
        Core.register<DeviceApi>(_ListingDeviceApi([_device(tag: 'fresh-tag')]));

        Core.register<Persistence>(Persistence(isSecure: false));
        final thisDevice = ThisDevice();
        Core.register<ThisDevice>(thisDevice);

        final actor = DeviceActor();
        await actor.setThisDeviceForLinked('fresh-tag', 'token', m);

        final after = await thisDevice.fetch(m);
        expect(after?.deviceTag, 'fresh-tag');
      });
    });
  });

}

/// Returns a fixed device list for fetchByToken, standing in for the account
/// that the incoming enrolment token belongs to.
class _ListingDeviceApi extends DeviceApi {
  final List<JsonDevice> devices;
  _ListingDeviceApi(this.devices);

  @override
  Future<List<JsonDevice>> fetchByToken(
          DeviceTag tag, String token, Marker m) async =>
      devices;
}
