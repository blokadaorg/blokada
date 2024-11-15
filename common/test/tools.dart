import 'package:common/core/config/act.dart';
import 'package:common/core/core.dart';
import 'package:common/core/core.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_api/src/backend/invoker.dart';

withTrace(Future Function(Marker m) fn) async {
  await dep.reset();
  LoggerCommands().attachAndSaveAct(mockedAct);

  final m = (goldenFileComparator as LocalFileComparator).basedir.pathSegments;
  final module = m[m.length - 2];
  final group = Invoker.current!.liveTest.groups.last.name;
  final test = Invoker.current!.liveTest.individualName.capitalize;

  await TestRunner().run("$module::$group::$test", fn);
}

mockAct(Dependable subject,
    {Flavor flavor = Flavor.og, Platform platform = Platform.ios}) {
  final act = ActScreenplay(ActScenario.test, flavor, platform);
  subject.setActForTest(act);
  return act;
}

final mockedAct = ActScreenplay(ActScenario.test, Flavor.og, Platform.ios);

class TestRunner with Logging {
  run(String name, Function(Marker) fn) {
    log(Markers.testing).trace(name, (m) async {
      await (fn(m));
    });
  }
}
