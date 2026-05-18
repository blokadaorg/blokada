import 'dart:convert';

import 'package:common/src/app_variants/v6/module/freemium/freemium.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../../tools.dart';
@GenerateNiceMocks([
  MockSpec<NotificationChannel>(),
  MockSpec<StageStore>(),
  MockSpec<Persistence>(),
  MockSpec<DeviceStore>(),
])
import 'weekly_refresh_test.mocks.dart';

void main() {
  group("WeeklyRefreshActor", () {
    test("cancels weeklyRefresh when account transitions to a non-freemium tier", () async {
      await withTrace((m) async {
        final ops = await _registerCommon();
        final actor = WeeklyRefreshActor();
        await actor.onCreate(m);

        final account = Core.get<AccountStore>();
        await account.propose(JsonAccount.fromJson(jsonDecode(_freemiumLibre)), m);
        verifyNever(ops.doCancel(NotificationId.weeklyRefresh.name));

        await account.propose(JsonAccount.fromJson(jsonDecode(_cloud)), m);
        verify(ops.doCancel(NotificationId.weeklyRefresh.name)).called(1);
      });
    });

    test("does not cancel weeklyRefresh while account stays freemium", () async {
      await withTrace((m) async {
        final ops = await _registerCommon();
        final actor = WeeklyRefreshActor();
        await actor.onCreate(m);

        final account = Core.get<AccountStore>();
        await account.propose(JsonAccount.fromJson(jsonDecode(_freemiumLibre)), m);
        await account.propose(JsonAccount.fromJson(jsonDecode(_freemiumLibreUpdated)), m);

        verifyNever(ops.doCancel(NotificationId.weeklyRefresh.name));
      });
    });

    test("cancels weeklyRefresh on cold start when account is already cloud", () async {
      await withTrace((m) async {
        final ops = await _registerCommon();
        final account = Core.get<AccountStore>();

        // Account becomes cloud before the actor subscribes — simulates a cold
        // start where AccountRefreshStore.init() emits accountChanged before
        // the freemium module is started.
        await account.propose(JsonAccount.fromJson(jsonDecode(_cloud)), m);

        final actor = WeeklyRefreshActor();
        await actor.onCreate(m);

        verify(ops.doCancel(NotificationId.weeklyRefresh.name)).called(1);
      });
    });
  });
}

Future<MockNotificationChannel> _registerCommon() async {
  final stage = MockStageStore();
  when(stage.route).thenReturn(StageRouteState.init());
  Core.register<StageStore>(stage);

  final persistence = MockPersistence();
  Core.register<Persistence>(persistence, tag: Persistence.secure);
  Core.register<Persistence>(persistence);

  Core.register<AccountStore>(AccountStore());
  Core.register<DeviceStore>(MockDeviceStore());
  Core.register<PaymentActor>(_FakePaymentActor());
  Core.register(NotificationsValue());
  Core.register(CurrentModalValue());
  Core.register(CurrentModalWidgetValue());
  Core.register(WeeklyLastOpenValue());

  final ops = MockNotificationChannel();
  Core.register<NotificationChannel>(ops);

  final notification = NotificationActor();
  Core.register<NotificationActor>(notification);

  return ops;
}

class _FakePaymentActor extends PaymentActor {
  _FakePaymentActor() {
    willAcceptOnValue(paymentSuccessful, [paymentClosed]);
  }
}

const _freemiumLibre = '''{
  "id":"mockedmocked",
  "active":false,
  "type":"libre",
  "attributes": {"freemium": true}
}''';

const _freemiumLibreUpdated = '''{
  "id":"mockedmocked",
  "active_until":"2026-01-01T00:00:00.000Z",
  "active":false,
  "type":"libre",
  "attributes": {"freemium": true}
}''';

const _cloud = '''{
  "id":"mockedmocked",
  "active_until":"2026-03-10T10:00:00.000Z",
  "active":true,
  "type":"cloud"
}''';
