import 'package:common/core/core.dart';
import 'package:common/platform/logger/logger.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_api/src/backend/invoker.dart';

withTrace(Future Function(Marker m) fn) async {
  await DI.di.reset();
  LoggerCommands().register(mockedAct);

  final m = (goldenFileComparator as LocalFileComparator).basedir.pathSegments;
  final module = m[m.length - 2];
  final group = Invoker.current!.liveTest.groups.last.name;
  final test = Invoker.current!.liveTest.individualName.capitalize;

  await TestRunner().run("$module::$group::$test", fn);
}

mockAct(Actor subject,
    {Flavor flavor = Flavor.v6, PlatformType platform = PlatformType.iOS}) {
  final act = ActScreenplay(ActScenario.test, flavor, platform);
  subject.act = act;
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
