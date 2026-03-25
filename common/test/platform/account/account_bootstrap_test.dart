import 'package:common/src/core/core.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/device/api.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../tools.dart';

class _MockPersistence extends Mock implements Persistence {}

class _MockDeviceApi extends Mock implements DeviceApi {}

class _FakeEnvActor extends EnvActor {
  _FakeEnvActor(this._deviceName);

  final String _deviceName;

  @override
  String get deviceName => _deviceName;
}

void main() {
  group('AccountStore bootstrap restore', () {
    test('restores cached account without notifying device listeners', () async {
      await withTrace((m) async {
        final persistence = _MockPersistence();
        when(
          () => persistence.loadJson(any(), any(), isBackup: any(named: 'isBackup')),
        ).thenAnswer(
          (_) async => {
            'id': 'acc-1',
            'active_until': '2026-03-10T10:00:00.000Z',
            'active': true,
            'type': 'plus',
          },
        );
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final stage = StageStore();
        stage.onRegister();

        final deviceApi = _MockDeviceApi();
        when(() => deviceApi.getDevice(any())).thenAnswer(
          (_) async => JsonDevice(
            deviceTag: 'device-1',
            lists: const ['a'],
            retention: '24h',
            paused: false,
            pausedForSeconds: 0,
            safeSearch: false,
          ),
        );
        Core.register<DeviceApi>(deviceApi);

        final account = AccountStore();
        Core.register<AccountStore>(account);
        Core.register<EnvActor>(_FakeEnvActor('Example iPhone'));

        final device = DeviceStore();
        Core.register<DeviceStore>(device);

        await account.restoreCachedForBootstrap(m);

        expect(account.account?.id, 'acc-1');
        verifyNever(() => deviceApi.getDevice(any()));
      });
    });

    test('bootstrap restore rejects cached account for another flavor', () async {
      await withTrace((m) async {
        final persistence = _MockPersistence();
        when(
          () => persistence.loadJson(any(), any(), isBackup: any(named: 'isBackup')),
        ).thenAnswer(
          (_) async => {
            'id': 'acc-family',
            'active_until': '2026-03-10T10:00:00.000Z',
            'active': true,
            'type': 'family',
          },
        );
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final account = AccountStore();
        Core.register<AccountStore>(account);

        await expectLater(
          account.restoreCachedForBootstrap(m),
          throwsA(isA<InvalidAccountId>()),
        );
      });
    });

    test('load still emits account change and triggers device refresh', () async {
      await withTrace((m) async {
        final persistence = _MockPersistence();
        when(
          () => persistence.loadJson(any(), any(), isBackup: any(named: 'isBackup')),
        ).thenAnswer(
          (_) async => {
            'id': 'acc-1',
            'active_until': '2026-03-10T10:00:00.000Z',
            'active': true,
            'type': 'plus',
          },
        );
        when(
          () => persistence.saveJson(any(), any(), any(), isBackup: any(named: 'isBackup')),
        ).thenAnswer((_) async {});
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final stage = StageStore();
        stage.onRegister();

        final deviceApi = _MockDeviceApi();
        when(() => deviceApi.getDevice(any())).thenAnswer(
          (_) async => JsonDevice(
            deviceTag: 'device-1',
            lists: const ['a'],
            retention: '24h',
            paused: false,
            pausedForSeconds: 0,
            safeSearch: false,
          ),
        );
        Core.register<DeviceApi>(deviceApi);

        final account = AccountStore();
        Core.register<AccountStore>(account);
        Core.register<EnvActor>(_FakeEnvActor('Example iPhone'));

        final device = DeviceStore();
        Core.register<DeviceStore>(device);

        await account.load(m);

        verify(() => deviceApi.getDevice(any())).called(1);
      });
    });
  });
}
