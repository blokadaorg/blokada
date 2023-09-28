import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../app/app.dart';
import '../persistence/persistence.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/trace.dart';

part 'onboard.g.dart';

const String _key = "onboard:state";

class OnboardStore = OnboardStoreBase with _$OnboardStore;

enum OnboardState { firstTime, accountDecided, completed }

abstract class OnboardStoreBase with Store, Traceable, Dependable {
  late final _persistence = dep<PersistenceService>();
  late final _stage = dep<StageStore>();
  late final _account = dep<AccountStore>();

  late final Act _act;

  OnboardStoreBase() {
    _account.addOn(accountIdChanged, onAccountIdChanged);
  }

  @override
  attach(Act act) {
    _act = act;
    depend<OnboardStore>(this as OnboardStore);
  }

  @observable
  OnboardState onboardState = OnboardState.firstTime;

  @action
  maybeShowOnboard(Trace parentTrace) async {
    if (!_act.isFamily()) return;

    return await traceWith(parentTrace, "maybeShowOnboard", (trace) async {
      final state = await _persistence.load(trace, _key);
      onboardState = OnboardState.values.firstWhere(
          (it) => it.toString() == state,
          orElse: () => OnboardState.firstTime);
      if (onboardState != OnboardState.firstTime) return;

      await _stage.setRoute(
          trace, StageKnownRoute.homeOverlayFamilyOnboard.path);
    });
  }

  @action
  setOnboardState(Trace parentTrace, OnboardState state) async {
    return await traceWith(parentTrace, "setOnboardState", (trace) async {
      onboardState = state;
      await _persistence.saveString(trace, _key, state.toString());
    });
  }

  @action
  Future<void> onAccountIdChanged(Trace parentTrace) async {
    if (onboardState != OnboardState.firstTime) return;

    return await traceWith(parentTrace, "onboardProceed", (trace) async {
      if (_account.type == AccountType.libre) return;
      await setOnboardState(trace, OnboardState.accountDecided);
    });
  }
}
