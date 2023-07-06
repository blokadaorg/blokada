import 'package:common/account/account.dart';
import 'package:common/notification/channel.pg.dart';
import 'package:common/notification/notification.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<NotificationOps>(),
  MockSpec<StageStore>(),
  MockSpec<AccountStore>(),
])
import 'notification_test.mocks.dart';

void main() {
  group("binder", () {
    test("onNotificationEvent", () async {
      await withTrace((trace) async {
        depend<AccountStore>(MockAccountStore());
        depend<StageStore>(MockStageStore());

        final store = NotificationStore();
        depend<NotificationStore>(store);

        final ops = MockNotificationOps();
        depend<NotificationOps>(ops);

        verifyNever(ops.doShow(any, any));

        await store.show(trace, NotificationId.accountExpired);
        verify(ops.doShow(any, any)).called(1);
      });
    });
  });
}
