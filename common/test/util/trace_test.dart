import 'package:common/tracer/collectors.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:common/tracer/tracer.dart';
import 'package:flutter_test/flutter_test.dart';

final _tracer = dep<TraceFactory>();

void main() {
  setUp(() async {
    await di.reset();
    depend<TraceFactory>(Tracer());
    depend<TraceCollector>(StdoutTraceCollector());
  });

  group("trace", () {
    test("nested tracing basic case", () async {
      final tParent = _tracer.newTrace("module1", "parent");
      tParent.addEvent("parent event");

      final tMiddle = tParent.start("module1", "middle");
      tMiddle.addEvent("middle event");

      final tChild = tMiddle.start("module1", "child");
      tChild.addEvent("child event");

      await tChild.end();
      await tMiddle.end();
      await tParent.end();
    });

    test("will return error unfinished trace", () async {
      final tParent = _tracer.newTrace("module1", "parent");
      final tMiddle = tParent.start("module1", "middle");
      final tMiddle2 = tParent.start("module1", "middle2");
      final tMiddle2Child = tMiddle2.start("module1", "middle2Child");
      final tChild = tMiddle.start("module1", "child");

      try {
        await tParent.end();
        fail("exception not thrown");
      } catch (e) {
        expect(
            e.toString(), "Bad state: Trace parent has 4 unfinished children");
      }

      await tChild.end();

      try {
        await tParent.end();
        fail("exception not thrown");
      } catch (e) {
        expect(
            e.toString(), "Bad state: Trace parent has 3 unfinished children");
      }

      await tMiddle2Child.end();
      await tMiddle2.end();

      try {
        throw Exception("doesn't matter");
      } on Exception catch (e, s) {
        await tMiddle.endWithFailure(e, s);
      }
      await tParent.end();
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

class _TestTraceAs with TraceOrigin {
  runSuccess(Future Function(Trace trace) deferred) async {
    await traceAs("test", (trace) async {}, deferred: deferred);
  }

  runFailing(Future Function(Trace trace) deferred) async {
    await traceAs("test", (trace) async {
      throw Exception("failing");
    }, deferred: deferred);
  }
}
