import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/platform/app/launch_context.dart';
import 'package:common/src/platform/device/api.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'dart:convert';
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
  group('BootstrapIdentityValue', () {
    test('persists secure account-bound bootstrap identity', () async {
      await withTrace((m) async {
        final persistence = _MockPersistence();
        when(() => persistence.save(any(), any(), any())).thenAnswer((_) async {});
        when(() => persistence.load(any(), any())).thenAnswer((_) async => null);
        when(() => persistence.delete(any(), any())).thenAnswer((_) async {});
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final value = BootstrapIdentityValue();
        final identity = BootstrapIdentity(
          accountId: 'acc-1',
          accountType: 'plus',
          activeUntil: '2026-03-10T10:00:00.000Z',
          deviceTag: 'device-1',
          deviceAlias: 'My iPhone',
          updatedAt: DateTime.utc(2026, 3, 10, 10),
        );

        await value.change(m, identity);

        verify(() => persistence.save(any(), any(), any())).called(1);
      });
    });

    test('omits null alias from persisted bootstrap identity payload', () async {
      await withTrace((m) async {
        final persistence = _MockPersistence();
        when(() => persistence.save(any(), any(), any())).thenAnswer((_) async {});
        when(() => persistence.load(any(), any())).thenAnswer((_) async => null);
        when(() => persistence.delete(any(), any())).thenAnswer((_) async {});
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final value = BootstrapIdentityValue();
        final identity = BootstrapIdentity(
          accountId: 'acc-1',
          accountType: 'plus',
          activeUntil: '2026-03-10T10:00:00.000Z',
          deviceTag: 'device-1',
          deviceAlias: null,
          updatedAt: DateTime.utc(2026, 3, 10, 10),
        );

        await value.change(m, identity);

        final captured = verify(() => persistence.save(any(), any(), captureAny())).captured;
        final saved = jsonDecode(captured.last as String) as Map<String, dynamic>;
        expect(saved.containsKey('deviceAlias'), isFalse);
      });
    });
  });

  group('DeviceStore bootstrap identity restore', () {
    test('restores deviceTag from bootstrap identity for matching account', () async {
      await withTrace((m) async {
        final stage = StageStore();
        stage.onRegister();
        Core.register<EnvActor>(_FakeEnvActor('Example iPhone'));
        final account = AccountStore();
        account.account = AccountState(
          'acc-1',
          JsonAccount(
            id: 'acc-1',
            activeUntil: '2026-03-10T10:00:00.000Z',
            active: true,
            type: 'plus',
          ),
        );
        Core.register<AccountStore>(account);

        final store = DeviceStore();
        final restored = await store.restoreBootstrapIdentity(
          BootstrapIdentity(
            accountId: 'acc-1',
            accountType: 'plus',
            activeUntil: '2026-03-10T10:00:00.000Z',
            deviceTag: 'device-1',
            deviceAlias: 'My iPhone',
            updatedAt: DateTime.utc(2026, 3, 10, 10),
          ),
          m,
        );

        expect(restored, isTrue);
        expect(store.deviceTag, 'device-1');
        expect(store.deviceAlias, 'My iPhone');
      });
    });

    test('rejects bootstrap identity from another account', () async {
      await withTrace((m) async {
        final stage = StageStore();
        stage.onRegister();
        Core.register<EnvActor>(_FakeEnvActor('Example iPhone'));
        final account = AccountStore();
        account.account = AccountState(
          'acc-1',
          JsonAccount(
            id: 'acc-1',
            activeUntil: '2026-03-10T10:00:00.000Z',
            active: true,
            type: 'plus',
          ),
        );
        Core.register<AccountStore>(account);

        final store = DeviceStore();
        store.deviceTag = 'existing-device';
        final restored = await store.restoreBootstrapIdentity(
          BootstrapIdentity(
            accountId: 'acc-2',
            accountType: 'plus',
            activeUntil: '2026-03-10T10:00:00.000Z',
            deviceTag: 'device-2',
            deviceAlias: 'Other device',
            updatedAt: DateTime.utc(2026, 3, 10, 10),
          ),
          m,
        );

        expect(restored, isFalse);
        expect(store.deviceTag, isNull);
      });
    });

    test('restores env device alias when cached bootstrap identity lacks one', () async {
      await withTrace((m) async {
        final stage = StageStore();
        stage.onRegister();
        Core.register<EnvActor>(_FakeEnvActor('Example iPhone'));
        final account = AccountStore();
        account.account = AccountState(
          'acc-1',
          JsonAccount(
            id: 'acc-1',
            activeUntil: '2026-03-10T10:00:00.000Z',
            active: true,
            type: 'plus',
          ),
        );
        Core.register<AccountStore>(account);

        final store = DeviceStore();
        final restored = await store.restoreBootstrapIdentity(
          BootstrapIdentity(
            accountId: 'acc-1',
            accountType: 'plus',
            activeUntil: '2026-03-10T10:00:00.000Z',
            deviceTag: 'device-1',
            deviceAlias: null,
            updatedAt: DateTime.utc(2026, 3, 10, 10),
          ),
          m,
        );

        expect(restored, isTrue);
        expect(store.deviceTag, 'device-1');
        expect(store.deviceAlias, 'Example iPhone');
      });
    });

    test('restores older bootstrap identity payloads without alias', () async {
      final identity = BootstrapIdentity.fromJson({
        'accountId': 'acc-1',
        'accountType': 'plus',
        'activeUntil': '2026-03-10T10:00:00.000Z',
        'deviceTag': 'device-1',
        'updatedAt': '2026-03-10T10:00:00.000Z',
      });

      expect(identity.deviceAlias, isNull);
      expect(identity.deviceTag, 'device-1');
    });

    test('restores older bootstrap identity payloads with null alias', () async {
      final identity = BootstrapIdentity.fromJson({
        'accountId': 'acc-1',
        'accountType': 'plus',
        'activeUntil': '2026-03-10T10:00:00.000Z',
        'deviceTag': 'device-1',
        'deviceAlias': null,
        'updatedAt': '2026-03-10T10:00:00.000Z',
      });

      expect(identity.deviceAlias, isNull);
      expect(identity.deviceTag, 'device-1');
    });

    test('publishes bootstrap identity when local device alias is set', () async {
      await withTrace((m) async {
        final persistence = _MockPersistence();
        when(() => persistence.save(any(), any(), any())).thenAnswer((_) async {});
        when(() => persistence.load(any(), any())).thenAnswer((_) async => null);
        when(() => persistence.delete(any(), any())).thenAnswer((_) async {});
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final bootstrapIdentity = BootstrapIdentityValue()..onRegister();

        final stage = StageStore();
        stage.onRegister();
        Core.register<EnvActor>(_FakeEnvActor('Example iPhone'));
        final account = AccountStore();
        account.account = AccountState(
          'acc-1',
          JsonAccount(
            id: 'acc-1',
            activeUntil: '2026-03-10T10:00:00.000Z',
            active: true,
            type: 'plus',
          ),
        );
        Core.register<AccountStore>(account);

        final store = DeviceStore();
        store.deviceTag = 'device-1';

        await store.setDeviceName('Renamed iPhone', m);

        final persisted = await bootstrapIdentity.fetch(m);
        expect(persisted?.deviceAlias, 'Renamed iPhone');
        expect(persisted?.deviceTag, 'device-1');

        final captured = verify(() => persistence.save(any(), any(), captureAny())).captured;
        final saved = jsonDecode(captured.last as String) as Map<String, dynamic>;
        expect(saved['deviceAlias'], 'Renamed iPhone');
      });
    });

    test('publishes bootstrap identity with env alias on first fetch', () async {
      await withTrace((m) async {
        final persistence = _MockPersistence();
        when(() => persistence.save(any(), any(), any())).thenAnswer((_) async {});
        when(() => persistence.load(any(), any())).thenAnswer((_) async => null);
        when(() => persistence.delete(any(), any())).thenAnswer((_) async {});
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final bootstrapIdentity = BootstrapIdentityValue()..onRegister();

        final stage = StageStore();
        stage.onRegister();
        Core.register<EnvActor>(_FakeEnvActor('Example iPhone'));
        final account = AccountStore();
        account.account = AccountState(
          'acc-1',
          JsonAccount(
            id: 'acc-1',
            activeUntil: '2026-03-10T10:00:00.000Z',
            active: true,
            type: 'plus',
          ),
        );
        Core.register<AccountStore>(account);

        final api = _MockDeviceApi();
        when(() => api.getDevice(any())).thenAnswer(
          (_) async => JsonDevice(
            deviceTag: 'device-1',
            lists: const [],
            retention: '1d',
            paused: false,
            pausedForSeconds: 0,
            safeSearch: false,
          ),
        );
        Core.register<DeviceApi>(api);

        final store = DeviceStore();

        await store.fetch(m, force: true);

        final afterFetch = await bootstrapIdentity.fetch(m);
        expect(afterFetch?.deviceTag, 'device-1');
        expect(afterFetch?.deviceAlias, 'Example iPhone');

        final captured = verify(() => persistence.save(any(), any(), captureAny())).captured;
        final saved = jsonDecode(captured.last as String) as Map<String, dynamic>;
        expect(saved['deviceAlias'], 'Example iPhone');
      });
    });

    test('preserves cached bootstrap alias until local alias is initialized', () async {
      await withTrace((m) async {
        final persistence = _MockPersistence();
        when(() => persistence.save(any(), any(), any())).thenAnswer((_) async {});
        when(() => persistence.load(any(), any())).thenAnswer((_) async => null);
        when(() => persistence.delete(any(), any())).thenAnswer((_) async {});
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final bootstrapIdentity = BootstrapIdentityValue()..onRegister();
        await bootstrapIdentity.change(
          m,
          BootstrapIdentity(
            accountId: 'acc-1',
            accountType: 'plus',
            activeUntil: '2026-03-10T10:00:00.000Z',
            deviceTag: 'device-0',
            deviceAlias: 'My iPhone',
            updatedAt: DateTime.utc(2026, 3, 10, 10),
          ),
        );

        final stage = StageStore();
        stage.onRegister();
        Core.register<EnvActor>(_FakeEnvActor(''));
        final account = AccountStore();
        account.account = AccountState(
          'acc-1',
          JsonAccount(
            id: 'acc-1',
            activeUntil: '2026-03-10T10:00:00.000Z',
            active: true,
            type: 'plus',
          ),
        );
        Core.register<AccountStore>(account);

        final api = _MockDeviceApi();
        when(() => api.getDevice(any())).thenAnswer(
          (_) async => JsonDevice(
            deviceTag: 'device-1',
            lists: const [],
            retention: '1d',
            paused: false,
            pausedForSeconds: 0,
            safeSearch: false,
          ),
        );
        Core.register<DeviceApi>(api);

        final store = DeviceStore();

        await store.fetch(m, force: true);

        final persisted = await bootstrapIdentity.fetch(m);
        expect(persisted?.deviceAlias, 'My iPhone');
        expect(persisted?.deviceTag, 'device-1');

        final captured = verify(() => persistence.save(any(), any(), captureAny())).captured;
        final saved = jsonDecode(captured.last as String) as Map<String, dynamic>;
        expect(saved['deviceAlias'], 'My iPhone');
      });
    });
  });
}
