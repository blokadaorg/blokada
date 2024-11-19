import 'package:common/core/core.dart';
import 'package:common/platform/app/app.dart';
import 'package:mobx/mobx.dart';

part 'home.g.dart';

class HomeStore = HomeStoreBase with _$HomeStore;

// Quite shit store used to control some flag. Remove eventually. TODO
abstract class HomeStoreBase with Store, Actor {
  late final _app = DI.get<AppStore>();

  HomeStoreBase() {
    autorun((_) {
      final status = _app.status;
      if (!status.isActive()) {
        resetPowerOn();
      }
    });
  }

  @override
  onRegister(Act act) {
    this.act = act;
    DI.register<HomeStore>(this as HomeStore);
  }

  @observable
  bool powerOnAnimationReady = false;

  @action
  resetPowerOn() {
    powerOnAnimationReady = false;
  }

  @action
  powerOnIsReady() {
    powerOnAnimationReady = true;
  }
}
