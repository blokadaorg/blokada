import 'dart:convert';

import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
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
  group("binder", () {
    test("onNotificationEvent", () async {
      await withTrace((m) async {
        Core.register<AccountStore>(MockAccountStore());
        Core.register<StageStore>(MockStageStore());

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
        Core.register<AccountStore>(MockAccountStore());
        Core.register<StageStore>(MockStageStore());
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
        Core.register<AccountStore>(MockAccountStore());
        Core.register<StageStore>(MockStageStore());
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

    test("notification tap queues privacy pulse navigation while app is backgrounded", () async {
      await withTrace((m) async {
        final stage = MockStageStore();
        when(stage.route).thenReturn(StageRouteState.init());
        Core.register<StageStore>(stage);
        Core.register<AccountStore>(MockAccountStore());
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

class _FakeWeeklyReportActor extends WeeklyReportActor {
  final WeeklyReportEvent event;

  _FakeWeeklyReportActor(this.event);

  @override
  Future<WeeklyReportEvent?> refreshAndPickForNotification(Marker m) async {
    return event;
  }
}
