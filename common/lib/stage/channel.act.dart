import 'package:mocktail/mocktail.dart';

import '../command/channel.pg.dart';
import '../entrypoint.dart';
import '../util/act.dart';
import '../util/di.dart';
import 'channel.pg.dart';

class MockStageOps extends Mock implements StageOps {}

StageOps getOps(Act act) {
  if (act.isProd()) {
    return StageOps();
  }

  final ops = MockStageOps();
  _actNormal(ops);
  return ops;
}

final _entrypoint = dep<Entrypoint>();

_actNormal(MockStageOps ops) {
  registerFallbackValue(StageModal.debug);
  registerFallbackValue(StageModal.fault);

  when(() => ops.doShowModal(any())).thenAnswer((p) async {
    _entrypoint.onCommandWithParam(
      CommandName.modalShown.name,
      (p.positionalArguments[0] as StageModal).name,
    );
  });

  when(() => ops.doDismissModal()).thenAnswer((_) async {
    _entrypoint.onCommand(CommandName.modalDismissed.name);
  });

  when(() => ops.doRouteChanged(any())).thenAnswer(ignore());
  when(() => ops.doShowNavbar(any())).thenAnswer(ignore());
}
