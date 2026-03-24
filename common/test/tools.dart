import 'package:common/src/core/core.dart';
import 'package:common/src/platform/core/core.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:logger/logger.dart';
// ignore_for_file: implementation_imports
import 'package:test_api/src/backend/invoker.dart';

withTrace(Future Function(Marker m) fn) async {
  final missingKeyCallback = Translations.missingKeyCallback;
  final missingTranslationCallback = Translations.missingTranslationCallback;
  BufferedTestLoggerOutput? testOutput;

  await Core.di.reset();
  Core.act = mockedAct;
  Core.config = CoreConfig();

  Translations.missingKeyCallback = (_, __) {};
  Translations.missingTranslationCallback = (_, __) {};

  try {
    final m = (goldenFileComparator as LocalFileComparator).basedir.pathSegments;
    final module = m[m.length - 2];
    final group = Invoker.current!.liveTest.groups.last.name;
    final test = Invoker.current!.liveTest.individualName.capitalize;
    final testName = "$module::$group::$test";

    testOutput = BufferedTestLoggerOutput(testName);
    await createTestPlatformCoreModule(testOutput);

    await TestRunner().run(testName, fn);
  } catch (_) {
    testOutput?.flushToPrintOnFailure();
    rethrow;
  } finally {
    testOutput?.clear();
    Translations.missingKeyCallback = missingKeyCallback;
    Translations.missingTranslationCallback = missingTranslationCallback;
  }
}

mockAct(Actor subject,
    {Flavor flavor = Flavor.v6, PlatformType platform = PlatformType.iOS}) {
  final act = ActScreenplay(ActScenario.test, flavor, platform);
  return act;
}

final mockedAct = ActScreenplay(ActScenario.test, Flavor.v6, PlatformType.iOS);

class TestRunner with Logging {
  run(String name, Function(Marker) fn) {
    log(Markers.testing).trace(name, (m) async {
      await (fn(m));
    });
  }
}

typedef FailurePrinter = void Function(String message);

FailurePrinter testFailurePrinter = printOnFailure;

Future<void> createTestPlatformCoreModule(LogOutput output) async {
  final channel = Core.act.isProd ? PlatformCoreChannel() : RuntimeCoreChannel();

  Core.register<PersistenceChannel>(channel);
  Core.register<LoggerChannel>(channel);
  Core.register(Logger(
    filter: ProductionFilter(),
    printer: defaultLoggerPrinter,
    output: output,
  ));
  Core.register(LogTracerActor());
  await commands.registerCommands(
    Markers.start,
    LoggerCommand().onRegisterCommands(),
  );
}

class BufferedTestLoggerOutput extends FileLoggerOutput {
  BufferedTestLoggerOutput(this.testName);

  final String testName;
  final List<String> _lines = [];

  @override
  void emitLines(OutputEvent event) {
    _lines.addAll(event.lines);
  }

  void flushToPrintOnFailure() {
    if (_lines.isEmpty) return;
    testFailurePrinter("Trace logs for failed test $testName:\n${_lines.join("\n")}");
  }

  void clear() {
    _lines.clear();
  }
}
