import 'package:mobx/mobx.dart';

import '../app/app.dart';
import '../persistence/persistence.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/trace.dart';

part 'onboard.g.dart';

const String _key = "onboard:seen";

class OnboardStore = OnboardStoreBase with _$OnboardStore;

abstract class OnboardStoreBase with Store, Traceable, Dependable {
  late final _persistence = dep<PersistenceService>();
  late final _stage = dep<StageStore>();

  late final Act _act;

  OnboardStoreBase() {}

  @override
  attach(Act act) {
    _act = act;
    depend<OnboardStore>(this as OnboardStore);
  }

  @observable
  bool onboardSeen = false;

  @action
  maybeShowOnboard(Trace parentTrace) async {
    if (!_act.isFamily()) return;

    return await traceWith(parentTrace, "maybeShowOnboard", (trace) async {
      final seen = await _persistence.load(trace, _key);
      onboardSeen = seen == "1";
      if (onboardSeen) return;

      await _stage.setRoute(
          trace, StageKnownRoute.homeOverlayFamilyOnboard.path);
      await _persistence.saveString(trace, _key, "1");
    });
  }
}
