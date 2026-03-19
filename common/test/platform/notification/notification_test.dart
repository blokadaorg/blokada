import 'dart:convert';

import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/account/refresh/refresh.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
@GenerateNiceMocks([
  MockSpec<NotificationChannel>(),
  MockSpec<StageStore>(),
  MockSpec<AccountStore>(),
])
import 'notification_test.mocks.dart';

void main() {
  group("command", () {
    test("does not register legacy apple token command", () {
      final command = NotificationCommand();
      final names = command.onRegisterCommands().map((it) => it.name).toList();

      expect(names, contains("FCMNOTIFICATIONTOKEN"));
      expect(names, isNot(contains("APPLENOTIFICATIONTOKEN")));
    });
  });

  group("binder", () {
    test("onNotificationEvent", () async {
      await withTrace((m) async {
        Core.register<AccountStore>(MockAccountStore());
        Core.register<StageStore>(MockStageStore());
        Core.register<PaymentActor>(_FakePaymentActor());

        Core.register(NotificationsValue());

        final store = NotificationActor();
        Core.register<NotificationActor>(store);

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        verifyNever(ops.doShow(any, any, any));

        await store.show(NotificationId.accountExpired, m);
        verify(ops.doShow(any, any, any)).called(1);
      });
    });

    test("handleFcmEvent uses schedule hint hour when provided", () async {
      await withTrace((m) async {
        Core.register<AccountStore>(_accountStoreWithAccount());
        Core.register<StageStore>(MockStageStore());
        Core.register<PaymentActor>(_FakePaymentActor());
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);

        final payload = jsonEncode({
          "v": "1",
          "type": "weekly_update",
          "event_id": "evt-1",
          "schedule_hint": "20",
        });

        await store.handleFcmEvent(m, payload);

        final captured = verify(ops.doShow(any, captureAny, any)).captured;
        final scheduledAt = DateTime.parse(captured[0] as String).toLocal();
        expect(scheduledAt.hour, 20);
        expect(scheduledAt.minute, 0);
        expect(scheduledAt.second, 0);
      });
    });

    test("handleFcmEvent schedules immediately when hint is missing", () async {
      await withTrace((m) async {
        Core.register<AccountStore>(_accountStoreWithAccount());
        Core.register<StageStore>(MockStageStore());
        Core.register<PaymentActor>(_FakePaymentActor());
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);

        final payload = jsonEncode({
          "v": "1",
          "type": "weekly_update",
          "event_id": "evt-1",
        });

        final start = DateTime.now();
        await store.handleFcmEvent(m, payload);

        final captured = verify(ops.doShow(any, captureAny, any)).captured;
        final scheduledAt = DateTime.parse(captured[0] as String).toLocal();
        expect(scheduledAt.isAfter(start), isTrue);
        expect(scheduledAt.difference(start), lessThan(const Duration(seconds: 20)));
      });
    });

    test("handleFcmEvent handles account expiry without weekly notification", () async {
      await withTrace((m) async {
        Core.register<AccountStore>(_accountStoreWithAccount());
        Core.register<StageStore>(MockStageStore());
        Core.register<PaymentActor>(_FakePaymentActor());
        Core.register(NotificationsValue());
        final accountRefresh = _FakeAccountRefreshStore();
        Core.register<AccountRefreshStore>(accountRefresh);

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);

        final payload = jsonEncode({
          "v": "1",
          "type": "account_expiry",
          "event_id": "evt-account-expiry",
        });

        await store.handleFcmEvent(m, payload);

        expect(accountRefresh.onAccountExpiryEvents, 1);
        verifyNever(ops.doShow(any, any, any));
      });
    });

    test("handleFcmEvent skips weekly update when account is unavailable", () async {
      await withTrace((m) async {
        Core.register<AccountStore>(AccountStore());
        Core.register<StageStore>(MockStageStore());
        Core.register(NotificationsValue());
        final weeklyReport = _FakeWeeklyReportActor(_weeklyEvent());
        Core.register<WeeklyReportActor>(weeklyReport);

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);

        final payload = jsonEncode({
          "v": "1",
          "type": "weekly_update",
          "event_id": "evt-1",
        });

        await store.handleFcmEvent(m, payload);

        expect(weeklyReport.refreshCalls, 0);
        verifyNever(ops.doShow(any, any, any));
      });
    });

    test("handleFcmEvent skips account expiry when account is unavailable", () async {
      await withTrace((m) async {
        Core.register<AccountStore>(AccountStore());
        Core.register<StageStore>(MockStageStore());
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));
        final accountRefresh = _FakeAccountRefreshStore();
        Core.register<AccountRefreshStore>(accountRefresh);

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);

        final payload = jsonEncode({
          "v": "1",
          "type": "account_expiry",
          "event_id": "evt-account-expiry",
        });

        await store.handleFcmEvent(m, payload);

        expect(accountRefresh.onAccountExpiryEvents, 0);
        verifyNever(ops.doShow(any, any, any));
      });
    });

    test("notification tap queues privacy pulse navigation while app is backgrounded", () async {
      await withTrace((m) async {
        final stage = MockStageStore();
        when(stage.route).thenReturn(StageRouteState.init());
        Core.register<StageStore>(stage);
        Core.register<AccountStore>(MockAccountStore());
        Core.register<PaymentActor>(_FakePaymentActor());
        Core.register<DeviceStore>(_MockDeviceStore());
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);
        Navigation.lastPath = null;

        await store.notificationTapped(m, NotificationId.weeklyReport.name);

        expect(Navigation.lastPath, isNull);
      });
    });

    test("notification tap opens privacy pulse after app becomes foreground", () async {
      await withTrace((m) async {
        final stage = MockStageStore();
        when(stage.route).thenReturn(StageRouteState.init());
        Core.register<StageStore>(stage);
        Core.register<AccountStore>(MockAccountStore());
        Core.register<PaymentActor>(_FakePaymentActor());
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);
        Navigation.lastPath = null;

        await store.notificationTapped(m, NotificationId.weeklyReport.name);
        await store.onRouteChanged(StageRouteState.init().newFg(), m);

        expect(Navigation.lastPath, Paths.privacyPulse);
      });
    });

    test("notification tap opens privacy pulse on actor start if app is already foreground",
        () async {
      await withTrace((m) async {
        final stage = MockStageStore();
        var route = StageRouteState.init();
        when(stage.route).thenAnswer((_) => route);
        Core.register<StageStore>(stage);
        Core.register<AccountStore>(MockAccountStore());
        Core.register<PaymentActor>(_FakePaymentActor());
        Core.register<DeviceStore>(_MockDeviceStore());
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);
        Navigation.lastPath = null;
        var opened = 0;
        Navigation.onNavigated = (_) {
          opened++;
        };

        await store.notificationTapped(m, NotificationId.weeklyReport.name);
        expect(Navigation.lastPath, isNull);

        route = StageRouteState.init().newFg();
        await store.onStart(m);

        expect(opened, 1);
        expect(Navigation.lastPath, Paths.privacyPulse);
        Navigation.onNavigated = (_) {};
      });
    });

    test("notification tap does not queue privacy pulse navigation when already on privacy pulse",
        () async {
      await withTrace((m) async {
        final stage = MockStageStore();
        when(stage.route).thenReturn(StageRouteState.init());
        Core.register<StageStore>(stage);
        Core.register<AccountStore>(MockAccountStore());
        Core.register<PaymentActor>(_FakePaymentActor());
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);
        Navigation.lastPath = Paths.privacyPulse;
        var opened = 0;
        Navigation.onNavigated = (_) {
          opened++;
        };

        await store.notificationTapped(m, NotificationId.weeklyReport.name);
        Navigation.lastPath = null;
        await store.onRouteChanged(StageRouteState.init().newFg(), m);

        expect(opened, 0);
        expect(Navigation.lastPath, isNull);
        Navigation.onNavigated = (_) {};
      });
    });

    test("non-restore payment schedules activity logging reminder when retention is disabled",
        () async {
      await withTrace((m) async {
        Navigation.isTabletMode = false;
        final stage = MockStageStore();
        when(stage.route).thenReturn(StageRouteState.init());
        final payment = _FakePaymentActor();
        final device = _FakeDeviceStore()..retentionValue = "";

        Core.register<StageStore>(stage);
        Core.register<AccountStore>(MockAccountStore());
        Core.register<DeviceStore>(device);
        Core.register<PaymentActor>(payment);
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);

        await store.onStart(m);
        await payment.emitValue(paymentSuccessful, false, m);

        final captured = verify(ops.doShow(
          NotificationId.activityLoggingReminder.name,
          captureAny,
          "Enable activity logging to receive your weekly Privacy Pulse reports.",
        )).captured;
        final scheduledAt = DateTime.parse(captured.single as String).toLocal();
        final delay = scheduledAt.difference(DateTime.now());
        expect(delay.inSeconds, inInclusiveRange(30, 120));
      });
    });

    test("restore payment does not schedule activity logging reminder", () async {
      await withTrace((m) async {
        Navigation.isTabletMode = false;
        final stage = MockStageStore();
        when(stage.route).thenReturn(StageRouteState.init());
        final payment = _FakePaymentActor();
        final device = _FakeDeviceStore()..retentionValue = "";

        Core.register<StageStore>(stage);
        Core.register<AccountStore>(MockAccountStore());
        Core.register<DeviceStore>(device);
        Core.register<PaymentActor>(payment);
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);

        await store.onStart(m);
        await payment.emitValue(paymentSuccessful, true, m);

        verifyNever(ops.doShow(NotificationId.activityLoggingReminder.name, any, any));
      });
    });

    test("enabled retention does not schedule activity logging reminder", () async {
      await withTrace((m) async {
        Navigation.isTabletMode = false;
        final stage = MockStageStore();
        when(stage.route).thenReturn(StageRouteState.init());
        final payment = _FakePaymentActor();
        final device = _FakeDeviceStore()..retentionValue = "24h";

        Core.register<StageStore>(stage);
        Core.register<AccountStore>(MockAccountStore());
        Core.register<DeviceStore>(device);
        Core.register<PaymentActor>(payment);
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);

        await store.onStart(m);
        await payment.emitValue(paymentSuccessful, false, m);

        verifyNever(ops.doShow(NotificationId.activityLoggingReminder.name, any, any));
        verify(ops.doCancel(NotificationId.activityLoggingReminder.name)).called(1);
      });
    });

    test("enabling retention cancels pending activity logging reminder", () async {
      await withTrace((m) async {
        Navigation.isTabletMode = false;
        final stage = MockStageStore();
        when(stage.route).thenReturn(StageRouteState.init());
        final payment = _FakePaymentActor();
        final device = _FakeDeviceStore()..retentionValue = "";

        Core.register<StageStore>(stage);
        Core.register<AccountStore>(MockAccountStore());
        Core.register<DeviceStore>(device);
        Core.register<PaymentActor>(payment);
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);

        await store.onStart(m);
        await payment.emitValue(paymentSuccessful, false, m);
        device.retentionValue = "24h";
        await device.emit(deviceChanged, "device-tag", m);

        verify(ops.doCancel(NotificationId.activityLoggingReminder.name)).called(1);
      });
    });

    test("activity logging reminder tap opens retention settings", () async {
      await withTrace((m) async {
        final stage = MockStageStore();
        when(stage.route).thenReturn(StageRouteState.init().newFg());
        Core.register<StageStore>(stage);
        Core.register<AccountStore>(MockAccountStore());
        Core.register<DeviceStore>(_MockDeviceStore());
        Core.register<PaymentActor>(_FakePaymentActor());
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);
        Navigation.lastPath = null;
        Navigation.isTabletMode = true;
        Navigation.openInTablet = (path, arguments) {
          Navigation.lastPath = path;
        };

        await store.notificationTapped(m, NotificationId.activityLoggingReminder.name);

        expect(Navigation.lastPath, Paths.settingsRetention);
      });
    });

    test("activity logging reminder tap defers navigation until app is foreground", () async {
      await withTrace((m) async {
        final stage = MockStageStore();
        when(stage.route).thenReturn(StageRouteState.init());
        Core.register<StageStore>(stage);
        Core.register<AccountStore>(MockAccountStore());
        Core.register<DeviceStore>(_MockDeviceStore());
        Core.register<PaymentActor>(_FakePaymentActor());
        Core.register(NotificationsValue());
        Core.register<WeeklyReportActor>(_FakeWeeklyReportActor(_weeklyEvent()));

        final ops = MockNotificationChannel();
        Core.register<NotificationChannel>(ops);

        final store = NotificationActor();
        Core.register<NotificationActor>(store);
        Navigation.lastPath = null;
        Navigation.isTabletMode = true;
        Navigation.openInTablet = (path, arguments) {
          Navigation.lastPath = path;
        };

        await store.notificationTapped(m, NotificationId.activityLoggingReminder.name);
        expect(Navigation.lastPath, isNull);

        when(stage.route).thenReturn(StageRouteState.init().newFg());
        await store.onRouteChanged(StageRouteState.init().newFg(), m);

        expect(Navigation.lastPath, Paths.settingsRetention);
      });
    });
  });

  group("resolveNotificationScheduleHint", () {
    final now = DateTime(2026, 2, 20, 10, 15, 0);

    test("returns today at requested hour when still in future", () {
      final scheduled = resolveNotificationScheduleHint("20", now);
      expect(scheduled, DateTime(2026, 2, 20, 20, 0, 0));
    });

    test("returns next day at requested hour when hour already passed", () {
      final scheduled = resolveNotificationScheduleHint("08", now);
      expect(scheduled, DateTime(2026, 2, 21, 8, 0, 0));
    });

    test("returns null for invalid or absent hints", () {
      final hints = [null, "", "  ", "abc", "-1", "24"];
      for (final hint in hints) {
        expect(resolveNotificationScheduleHint(hint, now), isNull);
      }
    });
  });
}

WeeklyReportEvent _weeklyEvent() {
  return WeeklyReportEvent(
    id: "event-id",
    title: "Weekly report",
    body: "Traffic changed",
    type: WeeklyReportEventType.mock,
    icon: WeeklyReportIcon.chart,
    score: 1,
    generatedAt: DateTime.now().toUtc(),
  );
}

AccountStore _accountStoreWithAccount() {
  final store = AccountStore();
  store.account = AccountState(
    "acc-1",
    JsonAccount(
      id: "acc-1",
      activeUntil: "2026-03-10T10:00:00.000Z",
      active: true,
      type: "plus",
    ),
  );
  return store;
}

class _FakeWeeklyReportActor extends WeeklyReportActor {
  final WeeklyReportEvent event;
  int refreshCalls = 0;

  _FakeWeeklyReportActor(this.event);

  @override
  Future<WeeklyReportEvent?> refreshAndPickForNotification(Marker m) async {
    refreshCalls++;
    return event;
  }
}

class _FakeAccountRefreshStore extends Mock implements AccountRefreshStore {
  int onAccountExpiryEvents = 0;

  @override
  Future<void> onAccountExpiryEvent(Marker m) async {
    onAccountExpiryEvents++;
  }
}

class _MockDeviceStore extends Mock implements DeviceStore {}

class _FakePaymentActor extends PaymentActor {
  _FakePaymentActor() {
    willAcceptOnValue(paymentSuccessful, [paymentClosed]);
  }
}

class _FakeDeviceStore extends Mock with Logging, Emitter implements DeviceStore {
  String? retentionValue;

  _FakeDeviceStore() {
    willAcceptOn([deviceChanged]);
  }

  @override
  String? get retention => retentionValue;

  @override
  Future<void> fetch(Marker m, {bool force = false}) async {}
}
