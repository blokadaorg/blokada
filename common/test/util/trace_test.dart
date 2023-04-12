import 'package:common/util/trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("trace", () {
    test("nested tracing basic case", () async {
      final tParent = DebugTrace.as("parent");
      tParent.addEvent("parent event");

      final tMiddle = tParent.start("middle");
      tMiddle.addEvent("middle event");

      final tChild = tMiddle.start("child");
      tChild.addEvent("child event");

      tChild.end();
      tMiddle.end();
      tParent.end();
    });

    test("will return error unfinished trace", () async {
      final tParent = DebugTrace.as("parent");
      final tMiddle = tParent.start("middle");
      final tChild = tMiddle.start("child");

      try {
        tParent.end();
        fail("exception not thrown");
      } catch (e) {
        expect(e.toString(), "Bad state: Trace parent has unfinished children");
      }

      tChild.end();

      try {
        tParent.end();
        fail("exception not thrown");
      } catch (e) {
        expect(e.toString(), "Bad state: Trace parent has unfinished children");
      }

      try {
        throw Exception("doesn't matter");
      } on Exception catch (e, s) {
        tMiddle.endWithFailure(e, s);
      }
      tParent.end();
    });
  });

  group("traceAs", () {
    test("willCallDeferredDespiteError", () async {
      bool deferredCalled = false;
      deferred(trace) async {
        deferredCalled = true;
      }

      final subject = _TestTraceAs();

      await subject.runSuccess(deferred);
      expect(deferredCalled, true);

      deferredCalled = false;
      await subject.runFailing(deferred);
      expect(deferredCalled, true);
    });
  });
}

class _TestTraceAs with Traceable {
  runSuccess(Future Function(Trace trace) deferred) async {
    await traceAs("test", (trace) async {}, deferred: deferred);
  }

  runFailing(Future Function(Trace trace) deferred) async {
    await traceAs("test", (trace) async {
      throw Exception("failing");
    }, deferred: deferred);
  }
}
