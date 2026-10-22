import 'package:common/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

class _CapturingOutput extends LogOutput {
  final List<OutputEvent> events = [];

  @override
  void output(OutputEvent event) => events.add(event);
}

void main() {
  test("an error logged outside a trace keeps its error", () async {
    await Core.di.reset();
    Core.act = ActScreenplay(ActScenario.test, Flavor.v6, PlatformType.iOS);
    Core.config = CoreConfig();

    final output = _CapturingOutput();
    Core.register(
      Logger(filter: ProductionFilter(), printer: defaultLoggerPrinter, output: output),
    );
    final tracer = LogTracerActor();

    final stack = StackTrace.current;
    tracer.sink(Markers.ui, Level.error, [
      "⛔ PaymentActor: Adapty: Failed purchase",
    ], err: Exception("AdaptyError code 1003"), stack: stack);

    expect(output.events, hasLength(1));
    expect(output.events.single.origin.error, isA<Exception>());
    expect(output.events.single.origin.stackTrace, same(stack));
    expect(output.events.single.lines.join("\n"), contains("AdaptyError code 1003"));
  });
}
