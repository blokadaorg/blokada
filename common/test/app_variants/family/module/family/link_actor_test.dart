import 'dart:async';
import 'package:common/src/app_variants/family/module/auth/auth.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../../tools.dart';

@GenerateNiceMocks([
  MockSpec<DeviceActor>(),
  MockSpec<AuthActor>(),
  MockSpec<StageStore>(),
  MockSpec<AccountStore>(),
  MockSpec<AccountState>(),
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

  group('LinkActor pending link', () {
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJkZXZpY2VfdGFnIjoiYWJjIn0.c2lnbmF0dXJl';
    const otherJwt =
        'eyJhbGciOiJIUzI1NiJ9.eyJkZXZpY2VfdGFnIjoieHl6In0.b3RoZXJzaWc';

    Future<LinkActor> setUpActor({
      required MockDeviceActor device,
      required MockAuthActor auth,
      JsonDevice? persistedThisDevice,
      String? persistedToken,
      AccountType accountType = AccountType.libre,
      bool persistedAccountActive = false,
      bool wasSetUp = false,
      required Marker m,
    }) async {
      Core.register<DeviceActor>(device);
      Core.register<AuthActor>(auth);
      Core.register<StageStore>(MockStageStore());
      final account = MockAccountStore();
      when(account.type).thenReturn(accountType);
      when(account.hasActivePersistedAccount(any))
          .thenAnswer((_) async => persistedAccountActive);
      Core.register<AccountStore>(account);
      // ThisDevice and CurrentToken read through Persistence, which withTrace
      // does not register. The channel it registers is an in-memory map.
      Core.register<Persistence>(Persistence(isSecure: false));

      final thisDevice = ThisDevice();
      Core.register<ThisDevice>(thisDevice);
      if (persistedThisDevice != null) {
        await thisDevice.change(m, persistedThisDevice);
      }

      final setUpFlag = WasSetUp();
      Core.register<WasSetUp>(setUpFlag);
      if (wasSetUp) await setUpFlag.change(m, true);

      final currentToken = CurrentToken();
      Core.register<CurrentToken>(currentToken);
      if (persistedToken != null) {
        await currentToken.change(m, persistedToken);
      }

      Core.register<FamilyLinkedMode>(FamilyLinkedMode());
      Core.register<PendingLinkValue>(PendingLinkValue());
      return LinkActor();
    }

    test('an active family account needs confirmation with no local state',
        () async {
      await withTrace((m) async {
        // Regression: an iOS reinstall restores the account id from the
        // keychain while ThisDevice and CurrentToken go with the sandbox. The
        // device is a set up parent but looks fresh to persistence, and the
        // link used to commit with no prompt.
        final actor = await setUpActor(
            device: MockDeviceActor(),
            auth: MockAuthActor(),
            accountType: AccountType.family,
            m: m);
        expect(await actor.needsConfirmation(m), isTrue);
      });
    });

    test('a stored account needs confirmation before startup loads it',
        () async {
      await withTrace((m) async {
        // A link can arrive before bootstrap resolves the account, and type
        // reports libre until it does. The stored account is the iOS reinstall
        // case: it survives the wipe that clears the device state.
        final actor = await setUpActor(
            device: MockDeviceActor(),
            auth: MockAuthActor(),
            persistedAccountActive: true,
            m: m);
        expect(await actor.needsConfirmation(m), isTrue);
      });
    });

    test('a device set up before needs confirmation after a token wipe',
        () async {
      await withTrace((m) async {
        // A failed token refresh clears ThisDevice and CurrentToken, and a
        // linked child holds a libre account, so WasSetUp is the only signal
        // left that this device has something to lose.
        final actor = await setUpActor(
            device: MockDeviceActor(),
            auth: MockAuthActor(),
            wasSetUp: true,
            m: m);
        expect(await actor.needsConfirmation(m), isTrue);
      });
    });

    test('token expiry backfills the setup flag on an upgraded install',
        () async {
      await withTrace((m) async {
        // Installs predating WasSetUp carry the flag false while holding a
        // device and token. Expiry wipes both, so the flag has to be recorded
        // while we still know the device was set up.
        final auth = MockAuthActor();
        final actor = await setUpActor(
            device: MockDeviceActor(),
            auth: auth,
            persistedThisDevice: _device('kid-tag', 'Kid', 'child-profile'),
            persistedToken: 'kid-token',
            m: m);
        await actor.onCreate(m);

        final expire =
            verify(auth.onTokenExpired = captureAny).captured.last as Function;
        await expire(m);

        expect(await Core.get<WasSetUp>().fetch(m), isTrue);
      });
    });

    test('a second link while one awaits an answer is dropped', () async {
      await withTrace((m) async {
        // Replacing the pending value under an open prompt is what produced
        // stacked dialogs and answers landing on the wrong token. One at a
        // time removes that at the source.
        final actor = await setUpActor(
            device: MockDeviceActor(), auth: MockAuthActor(), m: m);

        await actor.requestLink(jwt, m);
        await actor.requestLink(otherJwt, m);

        expect(Core.get<PendingLinkValue>().present, jwt);
      });
    });

    test('concurrent links before the value resolves still claim once',
        () async {
      await withTrace((m) async {
        // PendingLinkValue reports present == null until its first change
        // resolves, so a null check on it lets two cold-start links through.
        // The claim is synchronous and cannot interleave.
        final actor = await setUpActor(
            device: MockDeviceActor(), auth: MockAuthActor(), m: m);

        await Future.wait([
          actor.requestLink(jwt, m),
          actor.requestLink(otherJwt, m),
        ]);

        expect(Core.get<PendingLinkValue>().present, jwt);
      });
    });

    test('a link arriving mid-commit is dropped', () async {
      await withTrace((m) async {
        // The claim is held across _commitLink. useToken and
        // setThisDeviceForLinked persist separately, so a link accepted while
        // they are in flight could pair one family's token with another's tag.
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        final inFlight = Completer<DeviceTag>();
        when(auth.useToken(any, any)).thenAnswer((_) => inFlight.future);

        final actor = await setUpActor(device: device, auth: auth, m: m);

        await actor.requestLink(jwt, m);
        final commit = actor.confirmPendingLink(jwt, m);

        await actor.requestLink(otherJwt, m);
        expect(Core.get<PendingLinkValue>().present, isNull);

        inFlight.complete('new-tag');
        await commit;

        verify(auth.useToken(jwt, any)).called(1);
        verifyNever(auth.useToken(otherJwt, any));
      });
    });

    test('confirming a stale prompt does not commit a newer link', () async {
      await withTrace((m) async {
        // Defence in depth behind the one-at-a-time rule: an answer only ever
        // consumes the token its prompt was raised for.
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        when(auth.useToken(any, any)).thenAnswer((_) async => 'new-tag');

        final actor = await setUpActor(
            device: device, auth: auth, m: m);

        await Core.get<PendingLinkValue>().change(m, otherJwt);
        await actor.confirmPendingLink(jwt, m);

        verifyNever(auth.useToken(any, any));
        expect(Core.get<PendingLinkValue>().present, otherJwt);
      });
    });

    test('a rejected first link does not mark a fresh device as set up',
        () async {
      await withTrace((m) async {
        // useToken validates before persisting, so an expired or unreachable
        // candidate reaches the expiry callback with nothing stored. Marking
        // that device set up would put the re-home prompt on its first link.
        final auth = MockAuthActor();
        final actor = await setUpActor(
            device: MockDeviceActor(), auth: auth, m: m);
        await actor.onCreate(m);

        final expire =
            verify(auth.onTokenExpired = captureAny).captured.last as Function;
        await expire(m);

        expect(await Core.get<WasSetUp>().fetch(m), isFalse);
      });
    });

    test('a fresh device needs no confirmation', () async {
      await withTrace((m) async {
        final actor = await setUpActor(
            device: MockDeviceActor(), auth: MockAuthActor(), m: m);
        expect(await actor.needsConfirmation(m), isFalse);
      });
    });

    test('an already linked child needs confirmation', () async {
      await withTrace((m) async {
        final actor = await setUpActor(
          device: MockDeviceActor(),
          auth: MockAuthActor(),
          persistedToken: 'existing-token',
          m: m,
        );
        expect(await actor.needsConfirmation(m), isTrue);
      });
    });

    test('a configured parent device needs confirmation', () async {
      await withTrace((m) async {
        final actor = await setUpActor(
          device: MockDeviceActor(),
          auth: MockAuthActor(),
          persistedThisDevice: _device('parent-tag', 'Parent', 'p'),
          m: m,
        );
        expect(await actor.needsConfirmation(m), isTrue);
      });
    });

    test('requestLink parks the token without linking', () async {
      await withTrace((m) async {
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        final actor = await setUpActor(device: device, auth: auth, m: m);

        await actor.requestLink('$familyLinkBase?token=$jwt', m);

        expect(Core.get<PendingLinkValue>().present, jwt);
        verifyNever(auth.useToken(any, any));
        verifyNever(device.setThisDeviceForLinked(any, any, any,
            confirmed: anyNamed('confirmed')));
      });
    });

    test('requestLink rejects malformed input without parking it', () async {
      await withTrace((m) async {
        final actor = await setUpActor(
            device: MockDeviceActor(), auth: MockAuthActor(), m: m);

        await expectLater(actor.requestLink('not-a-token', m), throwsException);
        expect(Core.get<PendingLinkValue>().present, isNull);
        // Android's scanner and CommandActivity invoke FAMILYLINK directly and
        // drop the result, so without this the scan fails with no feedback.
        verify((Core.get<StageStore>() as MockStageStore)
                .showModal(StageModal.fault, any))
            .called(1);
      });
    });

    test('cancelPendingLink persists nothing', () async {
      await withTrace((m) async {
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        final actor = await setUpActor(
          device: device,
          auth: auth,
          persistedToken: 'existing-token',
          m: m,
        );

        await actor.requestLink(jwt, m);
        await actor.cancelPendingLink(jwt, m);

        expect(Core.get<PendingLinkValue>().present, isNull);
        // The regression found in manual testing: a rejected link must not
        // have overwritten the persisted token on the way in.
        expect(await Core.get<CurrentToken>().fetch(m), 'existing-token');
        verifyNever(auth.useToken(any, any));
        verifyNever(device.setThisDeviceForLinked(any, any, any,
            confirmed: anyNamed('confirmed')));
      });
    });

    test('confirmPendingLink commits with confirmed: true', () async {
      await withTrace((m) async {
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        when(auth.useToken(any, any)).thenAnswer((_) async => 'new-tag');

        final actor = await setUpActor(
          device: device,
          auth: auth,
          persistedThisDevice: _device('old-tag', 'Old', 'p'),
          m: m,
        );

        await actor.requestLink(jwt, m);
        await actor.confirmPendingLink(jwt, m);

        verify(auth.useToken(jwt, any)).called(1);
        verify(device.setThisDeviceForLinked('new-tag', jwt, any,
                confirmed: true))
            .called(1);
        expect(Core.get<PendingLinkValue>().present, isNull);
      });
    });

    test('a failed useToken leaves nothing behind', () async {
      await withTrace((m) async {
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        when(auth.useToken(any, any)).thenThrow(Exception('inactive account'));

        final actor = await setUpActor(
          device: device,
          auth: auth,
          persistedToken: 'existing-token',
          m: m,
        );

        await actor.requestLink(jwt, m);
        await expectLater(actor.confirmPendingLink(jwt, m), throwsException);

        expect(Core.get<PendingLinkValue>().present, isNull);
        verifyNever(device.setThisDeviceForLinked(any, any, any,
            confirmed: anyNamed('confirmed')));
      });
    });

    test('cmdLink parks the link instead of linking immediately', () async {
      await withTrace((m) async {
        final device = MockDeviceActor();
        final auth = MockAuthActor();
        final actor = await setUpActor(device: device, auth: auth, m: m);
        Core.register<LinkActor>(actor);

        final command = FamilyCommand();
        await command.cmdLink(m, ['$familyLinkBase?token=$jwt']);

        expect(Core.get<PendingLinkValue>().present, jwt);
        verifyNever(auth.useToken(any, any));
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
  )
    // late field, only assigned by fromJson. Persisting calls toJson, so a
    // constructor-built fixture needs it set explicitly.
    ..lastHeartbeat = '2026-01-01T00:00:00Z';
}

JsonProfile _profile(String id, String alias) {
  return JsonProfile(
    profileId: id,
    alias: alias,
    lists: const [],
    safeSearch: false,
  );
}
