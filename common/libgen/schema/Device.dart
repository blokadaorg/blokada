import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class DeviceOps {
  @async
  void doCloudEnabled(bool enabled);

  @async
  void doRetentionChanged(String retention);

  @async
  void doDeviceTagChanged(String deviceTag);
}

@FlutterApi()
abstract class DeviceEvents {
  @async
  void onEnableCloud(bool enable);

  @async
  void onSetRetention(String retention);
}
