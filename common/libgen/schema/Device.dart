import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class DeviceOps {
  @async
  void doCloudEnabled(bool enabled);

  @async
  void doRetentionChanged(String retention);

  @async
  void doDeviceTagChanged(String deviceTag);

  @async
  void doDeviceAliasChanged(String deviceAlias);
}
