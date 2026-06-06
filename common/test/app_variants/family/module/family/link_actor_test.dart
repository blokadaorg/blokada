import 'package:common/src/app_variants/family/module/auth/auth.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../../tools.dart';

@GenerateNiceMocks([
  MockSpec<DeviceActor>(),
  MockSpec<AuthActor>(),
])
import 'link_actor_test.mocks.dart';

void main() {
  group('LinkActor.updateLinkingDevice', () {
    test('renames without minting a new token or device tag', () async {
      await withTrace((m) async {
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        Core.register<DeviceActor>(device);
        Core.register<AuthActor>(auth);

        final original = _device('tag-1', 'Old name', 'child-profile');
        final profile = _profile('child-profile', 'Child');

        when(device.addDevice(any, any, any)).thenAnswer(
            (_) async => LinkingDevice(device: original, profile: profile));
        when(auth.createToken(any, any)).thenAnswer((_) async => 'token-1');

        final actor = LinkActor();
        final linking =
            await actor.initiateLinkDevice('Old name', profile, null, m);
        expect(linking.token, 'token-1');

        clearInteractions(auth);
        clearInteractions(device);

        final renamed = _device('tag-1', 'New name', 'child-profile');
        when(device.renameDevice(any, any, any))
            .thenAnswer((_) async => renamed);

        final updated = await actor.updateLinkingDevice(name: 'New name', m: m);

        expect(updated!.device.deviceTag, 'tag-1');
        expect(updated!.device.alias, 'New name');
        expect(updated!.token, 'token-1');
        expect(updated!.qrUrl, linking.qrUrl);
        verify(device.renameDevice(any, 'New name', any)).called(1);
        verifyNever(auth.createToken(any, any));
        verifyNever(device.deleteDevice(any, any));
        verifyNever(device.addDevice(any, any, any));
      });
    });

    test('changes profile without regenerating the token or selecting it globally',
        () async {
      await withTrace((m) async {
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        Core.register<DeviceActor>(device);
        Core.register<AuthActor>(auth);

        final original = _device('tag-1', 'Name', 'child-profile');
        final childProfile = _profile('child-profile', 'Child');
        final teenProfile = _profile('teen-profile', 'Teen');

        when(device.addDevice(any, any, any)).thenAnswer((_) async =>
            LinkingDevice(device: original, profile: childProfile));
        when(auth.createToken(any, any)).thenAnswer((_) async => 'token-1');

        final actor = LinkActor();
        final linking =
            await actor.initiateLinkDevice('Name', childProfile, null, m);

        clearInteractions(auth);
        clearInteractions(device);

        final reprofiled = _device('tag-1', 'Name', 'teen-profile');
        when(device.changeDeviceProfile(any, any, any,
                select: anyNamed('select')))
            .thenAnswer((_) async => reprofiled);

        final updated =
            await actor.updateLinkingDevice(profile: teenProfile, m: m);

        expect(updated!.device.deviceTag, 'tag-1');
        expect(updated!.device.profileId, 'teen-profile');
        expect(updated!.profile?.profileId, 'teen-profile');
        expect(updated!.token, 'token-1');
        expect(updated!.qrUrl, linking.qrUrl);
        verify(device.changeDeviceProfile(any, any, any, select: false))
            .called(1);
        verifyNever(auth.createToken(any, any));
        verifyNever(device.deleteDevice(any, any));
      });
    });

    test('skips the profile API call when the profile is unchanged', () async {
      await withTrace((m) async {
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        Core.register<DeviceActor>(device);
        Core.register<AuthActor>(auth);

        final original = _device('tag-1', 'Name', 'child-profile');
        final childProfile = _profile('child-profile', 'Child');

        when(device.addDevice(any, any, any)).thenAnswer((_) async =>
            LinkingDevice(device: original, profile: childProfile));
        when(auth.createToken(any, any)).thenAnswer((_) async => 'token-1');

        final actor = LinkActor();
        await actor.initiateLinkDevice('Name', childProfile, null, m);

        clearInteractions(auth);
        clearInteractions(device);

        final updated =
            await actor.updateLinkingDevice(profile: childProfile, m: m);

        expect(updated!.device.profileId, 'child-profile');
        expect(updated!.profile?.profileId, 'child-profile');
        expect(updated!.token, 'token-1');
        verifyNever(device.changeDeviceProfile(any, any, any,
            select: anyNamed('select')));
        verifyNever(auth.createToken(any, any));
      });
    });

    test('is a no-op when nothing is being linked', () async {
      await withTrace((m) async {
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        Core.register<DeviceActor>(device);
        Core.register<AuthActor>(auth);

        // No initiateLinkDevice: the link finished or was cancelled. A late tap
        // from a still-open edit dialog must not throw into the UI.
        final actor = LinkActor();

        final result = await actor.updateLinkingDevice(
            profile: _profile('child-profile', 'Child'), m: m);

        expect(result, isNull);
        verifyNever(device.renameDevice(any, any, any));
        verifyNever(device.changeDeviceProfile(any, any, any,
            select: anyNamed('select')));
      });
    });

    test('does not resurrect a session cancelled while awaiting', () async {
      await withTrace((m) async {
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        Core.register<DeviceActor>(device);
        Core.register<AuthActor>(auth);

        final original = _device('tag-1', 'Old name', 'child-profile');
        final profile = _profile('child-profile', 'Child');

        when(device.addDevice(any, any, any)).thenAnswer(
            (_) async => LinkingDevice(device: original, profile: profile));
        when(auth.createToken(any, any)).thenAnswer((_) async => 'token-1');

        final actor = LinkActor();
        await actor.initiateLinkDevice('Old name', profile, null, m);

        // The link is cancelled (e.g. sheet disposed) while the rename network
        // call is in flight. The in-place update must not write the device back.
        when(device.renameDevice(any, any, any)).thenAnswer((_) async {
          await actor.cancelLinkDevice(m);
          return _device('tag-1', 'New name', 'child-profile');
        });

        final result = await actor.updateLinkingDevice(name: 'New name', m: m);
        expect(result, isNull);

        // Session stays cleared: a follow-up edit is also a no-op, proving the
        // cancelled device was not resurrected into _linkingDevice.
        clearInteractions(device);
        final again =
            await actor.updateLinkingDevice(name: 'Another', m: m);
        expect(again, isNull);
        verifyNever(device.renameDevice(any, any, any));
      });
    });
  });
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
