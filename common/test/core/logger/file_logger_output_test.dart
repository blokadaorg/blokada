import 'dart:async';

import 'package:common/src/core/core.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/core/channel.pg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/src/log_event.dart';
import 'package:logger/src/log_level.dart';
import 'package:logger/src/output_event.dart';

class _FakeLoggerChannel with LoggerChannel {
  final List<String> batches = [];
  String? filename;

  @override
  Future<void> doShareFile() async {}

  @override
  Future<void> doSaveBatch(String batch) async {
    batches.add(batch);
  }

  @override
  Future<void> doUseFilename(String filename) async {
    this.filename = filename;
  }
}

void main() {
  test("emits test logs immediately", () async {
    final printed = <String>[];
    await runZoned(() async {
      await Core.di.reset();
      Core.act = ActScreenplay(ActScenario.test, Flavor.v6, PlatformType.iOS);
      Core.config = CoreConfig();

      final channel = _FakeLoggerChannel();
      Core.register<LoggerChannel>(channel);

      final output = FileLoggerOutput();

      output.output(OutputEvent(
        LogEvent(Level.trace, "trace one"),
        ["trace one"],
      ));
      output.output(OutputEvent(
        LogEvent(Level.info, "info two"),
        ["info two"],
      ));

      expect(channel.filename, isNotNull);
      expect(channel.batches, [
        "trace one\n",
        "info two\n",
      ]);
    }, zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        printed.add(line);
      },
    ));

    expect(printed, [
      "trace one",
      "info two",
    ]);
  });
}
