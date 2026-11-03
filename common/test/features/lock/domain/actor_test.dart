import 'package:common/src/core/core.dart';
import 'package:common/src/features/lock/domain/lock.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../tools.dart';

@GenerateNiceMocks([MockSpec<StageStore>(), MockSpec<Persistence>()])
import 'actor_test.mocks.dart';

/// Registers everything LockActor resolves, with no PIN stored yet.
MockPersistence _registerDeps() {
  Core.register<StageStore>(MockStageStore());
  final persistence = MockPersistence();
  when(persistence.load(any, any)).thenAnswer((_) => Future.value(null));
  Core.register<Persistence>(persistence);
  Core.register(IsLocked());
  Core.register(HasPin());
  Core.register(ExistingPin());
  return persistence;
}

void main() {
  group("lock", () {
    test("an invalid PIN throws and raises no stage modal", () async {
      await withTrace((m) async {
        final persistence = _registerDeps();
        final subject = LockActor();

        for (final pin in ["12", "12345", "12a4", "-123", ""]) {
          await expectLater(subject.lock(m, pin), throwsA(isA<InvalidPinException>()));
          await expectLater(subject.setLock(m, pin), throwsA(isA<InvalidPinException>()));
        }

        // Any modal here would hold the stage's modal slot, which neither
        // platform renders for a bad PIN.
        verifyNever((Core.get<StageStore>() as MockStageStore).showModal(any, any));
        verifyNever(persistence.save(any, any, any));
        expect(Core.get<IsLocked>().now, false);
        expect(Core.get<HasPin>().now, false);
      });
    });

    test("a four-digit PIN is stored and locks the app", () async {
      await withTrace((m) async {
        final persistence = _registerDeps();
        final subject = LockActor();

        await subject.lock(m, "1234");

        verify(persistence.save(any, "lock:pin", "1234")).called(1);
        expect(Core.get<IsLocked>().now, true);
        expect(Core.get<HasPin>().now, true);
      });
    });
  });
}
