import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:common/util/tracer.dart' as tracer;
import 'package:common/util/tracer.dart';
import 'package:flutter_test/flutter_test.dart';

final _tracer = dep<Tracer>();

void main() {
  setUp(() async {
    await di.reset();
    depend<Tracer>(DefaultTracer());
    depend<TraceCollector>(StdoutCollector());
  });

  group("trace", () {
    test("nested tracing basic case", () async {
      final tParent = _tracer.newTrace("root", "parent");
      tParent.addEvent("parent event");

      final tMiddle = tParent.start("middle");
      tMiddle.addEvent("middle event");

      final tChild = tMiddle.start("child");
      tChild.addEvent("child event");

      await tChild.end();
      await tMiddle.end();
      await tParent.end();
    });

    test("will return error unfinished trace", () async {
      final tParent = _tracer.newTrace("root", "parent");
      final tMiddle = tParent.start("middle");
      final tMiddle2 = tParent.start("middle2");
      final tMiddle2Child = tMiddle2.start("middle2Child");
      final tChild = tMiddle.start("child");

      try {
        await tParent.end();
        fail("exception not thrown");
      } catch (e) {
        expect(e.toString(), "Bad state: Trace parent has unfinished children");
      }

      await tChild.end();

      try {
        await tParent.end();
        fail("exception not thrown");
      } catch (e) {
        expect(e.toString(), "Bad state: Trace parent has unfinished children");
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
