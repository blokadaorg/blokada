import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class StageOps {
  @async
  void doShowModal(String modal);

  @async
  void doNavPathChanged(String path);
}

@FlutterApi()
abstract class StageEvents {
  @async
  void onForeground(bool isForeground);

  @async
  void onNavPathChanged(String path);

  @async
  void onModalTriggered(String modal);

  @async
  void onModalDismissedByUser();

  @async
  void onModalDismissedByPlatform();
}
