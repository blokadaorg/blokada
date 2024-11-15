import 'package:common/core/core.dart';
import 'package:common/util/emitter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tools.dart';

void main() {
  group("emitter", () {
    test("basicTest", () async {
      await withTrace((m) async {
        int listenerCalledTimes = 0;
        listener(_) => listenerCalledTimes++;

        final subject = _Subject();

        // When not setup properly, will throw
        try {
          subject.addOn(_event, listener);
          throw Exception("Test should throw exception");
        } catch (_) {}

        try {
          await subject.emit(_event, true, m);
          throw Exception("Test should throw exception");
        } catch (_) {}

        subject.willAcceptOn([_event]);

        // Now can add listener
        subject.addOn(_event, listener);

        // Emitting will trigger listener
        expect(listenerCalledTimes, 0);
        await subject.emit(_event, true, m);
        expect(listenerCalledTimes, 1);
        await subject.emit(_event, true, m);
        expect(listenerCalledTimes, 2);
      });
    });
  });
}

final _event = EmitterEvent("testEvent");

class _Subject with Logging, Emitter {}
