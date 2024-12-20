import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class DeviceOps {
  @async
  void doDeviceTagChanged(String deviceTag);
}
