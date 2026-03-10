import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/app/launch_context.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../tools.dart';

class _MockPersistence extends Mock implements Persistence {}

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
          updatedAt: DateTime.utc(2026, 3, 10, 10),
        );

        await value.change(m, identity);

        verify(() => persistence.save(any(), any(), any())).called(1);
      });
    });
  });

  group('DeviceStore bootstrap identity restore', () {
    test('restores deviceTag from bootstrap identity for matching account', () async {
      await withTrace((m) async {
        final stage = StageStore();
        stage.onRegister();
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
            updatedAt: DateTime.utc(2026, 3, 10, 10),
          ),
          m,
        );

        expect(restored, isTrue);
        expect(store.deviceTag, 'device-1');
      });
    });

    test('rejects bootstrap identity from another account', () async {
      await withTrace((m) async {
        final stage = StageStore();
        stage.onRegister();
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
            updatedAt: DateTime.utc(2026, 3, 10, 10),
          ),
          m,
        );

        expect(restored, isFalse);
        expect(store.deviceTag, isNull);
      });
    });
  });
}
