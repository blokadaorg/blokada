import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class PlusOps {
  @async
  void doPlusEnabledChanged(bool plusEnabled);
}

@FlutterApi()
abstract class PlusEvents {
  @async
  void onNewPlus(String gatewayPublicKey);

  @async
  void onClearPlus();

  @async
  void onSwitchPlus(bool active);
}
