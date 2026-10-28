import 'package:common/src/core/core.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';

@GenerateNiceMocks([MockSpec<Persistence>(), MockSpec<NotificationActor>(), MockSpec<StageStore>()])
import 'unread_actor_test.mocks.dart';

/// Registers what SupportUnreadActor resolves, with the flag stored as unset.
SupportUnread _registerDeps() {
  final persistence = MockPersistence();
  when(persistence.load(any, any)).thenAnswer((_) => Future.value(null));
  when(persistence.save(any, any, any, isBackup: anyNamed("isBackup"))).thenAnswer((_) async {});
  Core.register<Persistence>(persistence);
  Core.register<NotificationActor>(MockNotificationActor());
  Core.register<StageStore>(MockStageStore());

  final unread = SupportUnread();
  Core.register<SupportUnread>(unread);
  return unread;
}

void main() {
  group("SupportUnreadActor", () {
    test("a reply while the sheet is open sets no unread flag", () async {
      await withTrace((m) async {
        final unread = _registerDeps();
        await unread.change(m, false);
        final subject = SupportUnreadActor();

        subject.sheetOpened();
        await subject.newMessage(m, "reply");

        expect(unread.present, isFalse);
      });
    });

    test("a reply after the sheet was closed sets the unread flag", () async {
      await withTrace((m) async {
        final unread = _registerDeps();
        await unread.change(m, false);
        final subject = SupportUnreadActor();

        subject.sheetOpened();
        subject.sheetClosed();
        await subject.newMessage(m, "reply");

        expect(unread.present, isTrue);
      });
    });

    test("a reply while the sheet is open in the background still notifies", () async {
      await withTrace((m) async {
        final unread = _registerDeps();
        await unread.change(m, false);
        final subject = SupportUnreadActor();

        subject.sheetOpened();
        subject.isForeground = false;
        await subject.newMessage(m, "reply");

        expect(unread.present, isTrue);
        verify(
          Core.get<NotificationActor>().showWithBody(NotificationId.supportNewMessage, m, "reply"),
        ).called(1);
      });
    });

    test("opening the sheet clears the unread flag", () async {
      await withTrace((m) async {
        final unread = _registerDeps();
        await unread.change(m, true);
        final subject = SupportUnreadActor();

        subject.sheetOpened();
        await Future<void>.delayed(Duration.zero);

        expect(unread.present, isFalse);
      });
    });
  });
}
