import 'package:mobx/mobx.dart';

import '../../app/app.dart';
import '../../util/di.dart';

part 'home.g.dart';

class HomeStore = HomeStoreBase with _$HomeStore;

// Quite shit store used to control some flag. Remove eventually. TODO
abstract class HomeStoreBase with Store {
  late final _app = di<AppStore>();

  HomeStoreBase() {
    autorun((_) {
      final status = _app.status;
      if (!status.isActive()) {
        resetPowerOn();
      }
    });
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

Future<void> init() async {
  di.registerSingleton<HomeStore>(HomeStore());
}
