import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/stage/stage.dart';
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
  });
}
