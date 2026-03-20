import 'package:common/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'tools.dart';

class _Probe with Logging {
  void info(Marker m, String message) {
    log(m).i(message);
  }
}

void main() {
  group("withTrace", () {
    late FailurePrinter originalPrinter;
    late List<String> failures;
    final probe = _Probe();

    setUp(() {
      originalPrinter = testFailurePrinter;
      failures = [];
      testFailurePrinter = failures.add;
    });

    tearDown(() {
      testFailurePrinter = originalPrinter;
    });

    test("does not print buffered logs for passing tests", () async {
      await withTrace((m) async {
        probe.info(m, "passing info");
      });

      expect(failures, isEmpty);
    });

    test("flushes buffered logs to the failure printer", () async {
      await Core.di.reset();
      Core.act = mockedAct;
      Core.config = CoreConfig();
      Core.register<LoggerChannel>(_FakeLoggerChannel());

      final output = BufferedTestLoggerOutput("module::group::test");
      output.output(OutputEvent(
        LogEvent(Level.info, "failing info"),
        ["failing info"],
      ));
      output.flushToPrintOnFailure();

      expect(failures, hasLength(1));
      expect(failures.single, contains("Trace logs for failed test module::group::test"));
      expect(failures.single, contains("failing info"));
    });
  });
}

class _FakeLoggerChannel with LoggerChannel {
  @override
  Future<void> doSaveBatch(String batch) async {}

  @override
  Future<void> doShareFile() async {}

  @override
  Future<void> doUseFilename(String filename) async {}
}
