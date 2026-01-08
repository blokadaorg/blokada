import 'package:common/src/core/core.dart';
import 'package:mocktail/mocktail.dart';

import '../command/channel.pg.dart';
import '../command/command.dart';
import 'channel.pg.dart';

class MockStageOps extends Mock implements StageOps {}

StageOps getOps() {
  if (Core.act.isProd) {
    return StageOps();
  }

  final ops = MockStageOps();
  _actNormal(ops);
  return ops;
}

final _command = Core.get<CommandStore>();

_actNormal(MockStageOps ops) {
  registerFallbackValue(StageModal.debug);
  registerFallbackValue(StageModal.fault);

  when(() => ops.doShowModal(any())).thenAnswer((p) async {
    _command.onCommandWithParam(
      CommandName.modalShown.name,
      (p.positionalArguments[0] as StageModal).name,
      Markers.root,
    );
  });

  when(() => ops.doDismissModal()).thenAnswer((_) async {
    _command.onCommand(CommandName.modalDismissed.name, Markers.root);
  });

  when(() => ops.doHomeReached()).thenAnswer(ignore());
}
