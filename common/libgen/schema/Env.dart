import 'package:pigeon/pigeon.dart';

class EnvPayload {
  final String appVersion;
  final String osVersion;
  final String buildFlavor;
  final String buildType;
  final String cpu;
  final String deviceBrand;
  final String deviceModel;
  final String deviceName;

  EnvPayload(this.appVersion, this.osVersion, this.buildFlavor, this.buildType,
      this.cpu, this.deviceBrand, this.deviceModel, this.deviceName);
}

@HostApi()
abstract class EnvOps {
  @async
  EnvPayload doGetEnvPayload();

  @async
  void doUserAgentChanged(String userAgent);
}
