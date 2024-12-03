import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/notification/channel.pg.dart';
import 'package:common/platform/notification/notification.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
@GenerateNiceMocks([
  MockSpec<NotificationOps>(),
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

        final store = NotificationStore();
        Core.register<NotificationStore>(store);

        final ops = MockNotificationOps();
        Core.register<NotificationOps>(ops);

        verifyNever(ops.doShow(any, any, any));

        await store.show(NotificationId.accountExpired, m);
        verify(ops.doShow(any, any, any)).called(1);
      });
    });
  });
}
