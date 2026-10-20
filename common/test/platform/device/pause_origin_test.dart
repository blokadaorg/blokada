import 'package:common/src/core/core.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/app/launch_context.dart';
import 'package:common/src/platform/device/api.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
import 'device_test.mocks.dart';
import 'pause_origin.dart';

JsonDevice _device({required bool paused}) => JsonDevice(
  deviceTag: "some-tag",
  lists: ["a"],
  retention: "",
  paused: paused,
  pausedForSeconds: 0,
  safeSearch: false,
);

class _FakeEnvActor extends EnvActor {
  @override
  String get deviceName => 'Example iPhone';
}

void main() {
  group('isPausedElsewhere', () {
    test('only a known, foreign pause on an active account', () {
      expect(
        isPausedElsewhere(accountActive: true, cloudEnabled: false, issuedHere: false),
        isTrue,
      );
      expect(
        isPausedElsewhere(accountActive: true, cloudEnabled: false, issuedHere: true),
        isFalse,
      );
      // Unknown origin (never observed) does not blame another device.
      expect(
        isPausedElsewhere(accountActive: true, cloudEnabled: false, issuedHere: null),
        isFalse,
      );
      expect(
        isPausedElsewhere(accountActive: true, cloudEnabled: true, issuedHere: false),
        isFalse,
      );
      expect(
        isPausedElsewhere(accountActive: true, cloudEnabled: null, issuedHere: false),
        isFalse,
      );
      // Expired: resuming would open the paywall, so no "Resume" claim.
      expect(
        isPausedElsewhere(accountActive: false, cloudEnabled: false, issuedHere: false),
        isFalse,
      );
    });
  });

  group('DeviceStore pause origin', () {
    late MockDeviceApi api;
    late PauseIssuedHereValue origin;
    late DeviceStore subject;

    void setup({required bool pausedOnServer}) {
      Core.register<StageStore>(MockStageStore());
      Core.register<AccountStore>(MockAccountStore());
      Core.register<EnvActor>(_FakeEnvActor());
      origin = registerMemoryPauseOrigin();
      api = MockDeviceApi();
      when(api.getDevice(any)).thenAnswer((_) async => _device(paused: pausedOnServer));
      Core.register<DeviceApi>(api);
      subject = DeviceStore();
      mockAct(subject);
      subject.deviceTag = "some-tag";
    }

    test('pausing here marks the pause as ours', () async {
      await withTrace((m) async {
        setup(pausedOnServer: true);
        subject.cloudEnabled = true;

        await subject.setCloudEnabled(m, false);

        expect(origin.present, isTrue);
        expect(
          isPausedElsewhere(
            accountActive: true,
            cloudEnabled: subject.cloudEnabled,
            issuedHere: origin.present,
          ),
          isFalse,
        );
      });
    });

    test('resuming here clears it', () async {
      await withTrace((m) async {
        setup(pausedOnServer: false);
        subject.cloudEnabled = false;
        await origin.change(m, true);

        await subject.setCloudEnabled(m, true);

        expect(origin.present, isFalse);
      });
    });

    test('a pause seen after an unpaused state came from another device', () async {
      await withTrace((m) async {
        setup(pausedOnServer: false);
        await subject.fetch(m, force: true);
        expect(origin.present, isFalse);

        // Another device pauses the account.
        when(api.getDevice(any)).thenAnswer((_) async => _device(paused: true));
        await subject.fetch(m, force: true);

        expect(subject.cloudEnabled, isFalse);
        expect(origin.present, isFalse);
        expect(
          isPausedElsewhere(
            accountActive: true,
            cloudEnabled: subject.cloudEnabled,
            issuedHere: origin.present,
          ),
          isTrue,
        );
      });
    });

    test('a pause first seen on a paused account stays of unknown origin', () async {
      await withTrace((m) async {
        setup(pausedOnServer: true);

        await subject.fetch(m, force: true);

        expect(origin.present, isNull);
      });
    });

    test('switching account forgets the previous account\'s pause', () async {
      await withTrace((m) async {
        setup(pausedOnServer: true);
        Core.register<BootstrapIdentityValue>(
          BootstrapIdentityValue()
            ..load = ((_) async => null)
            ..save = ((_, _) async {}),
        );
        await origin.change(m, true);

        await subject.onAccountIdChanged(m);

        expect(origin.present, isNull);
      });
    });
  });
}
