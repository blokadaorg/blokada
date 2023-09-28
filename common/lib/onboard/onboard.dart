import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../app/app.dart';
import '../perm/perm.dart';
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
  late final _app = dep<AppStore>();

  late final Act _act;

  OnboardStoreBase() {
    _account.addOn(accountIdChanged, onAccountIdChanged);
    _app.addOn(appStatusChanged, onAppStatusChanged);
  }

  @override
  attach(Act act) {
    _act = act;
    depend<OnboardStore>(this as OnboardStore);
  }

  @observable
  OnboardState onboardState = OnboardState.firstTime;

  bool get isOnboarded => onboardState == OnboardState.completed;

  // React to account changes to show the proper onboarding
  @action
  Future<void> onAccountIdChanged(Trace parentTrace) async {
    if (!_act.isFamily()) {
      // Old flow for the main flavor, just show the onboarding modal
      return await traceWith(parentTrace, "onboardProceed", (trace) async {
        await _stage.showModal(trace, StageModal.perms);
      });
    }

    if (!_account.type.isActive()) return;
    if (onboardState != OnboardState.firstTime) return;

    return await traceWith(parentTrace, "onboardProceed", (trace) async {
      await setOnboardState(trace, OnboardState.accountDecided);
    });
  }

  @action
  Future<void> onAppStatusChanged(Trace parentTrace) async {
    return await traceWith(parentTrace, "onboardFinish", (trace) async {
      if (_app.status.isActive()) {
        await setOnboardState(trace, OnboardState.completed);
      }
    });
  }

  // Show the welcome screen on the first start (family only)
  @action
  maybeShowOnboardOnStart(Trace parentTrace) async {
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
}
