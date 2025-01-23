part of 'env.dart';

class EnvInfo {
  final String appVersion;
  final String osVersion;
  final String buildFlavor;
  final String buildType;
  final String cpu;
  final String deviceBrand;
  final String deviceModel;
  final String deviceName;

  EnvInfo(
    this.appVersion,
    this.osVersion,
    this.buildFlavor,
    this.buildType,
    this.cpu,
    this.deviceBrand,
    this.deviceModel,
    this.deviceName,
  );

  toSimpleString() {
    return "appVersion: $appVersion, "
        "osVersion: $osVersion, "
        "buildFlavor: $buildFlavor, "
        "buildType: $buildType, "
        "cpu: $cpu, "
        "deviceBrand: $deviceBrand, "
        "deviceModel: $deviceModel, "
        "deviceName: $deviceName";
  }
}
