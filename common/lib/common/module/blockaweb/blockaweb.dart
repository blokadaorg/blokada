import 'package:common/core/core.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/util/mobx.dart';

class BlockaWebModule with Module {
  @override
  onCreateModule() async {
    await register(BlockaWebActor());
  }
}

const _blockaWebActiveKey = "blockawebActive";

class BlockaWebActor with Actor, Logging {
  late final _app = Core.get<AppStore>();
  late final _persistence = Core.get<Persistence>();

  @override
  onStart(Marker m) async {
    reactionOnStore((_) => _app.status, (retention) async {
      if (_app.status.isActive()) {
        await _persistence.save(m, _blockaWebActiveKey, "1");
      } else {
        await _persistence.save(m, _blockaWebActiveKey, "");
      }
    });
  }
}
