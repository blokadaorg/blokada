part of 'onboard.dart';

class V6PrivateDnsStringProvider extends PrivateDnsStringProvider {
  late final _device = Core.get<DeviceStore>();
  late final _check = Core.get<PrivateDnsCheck>();

  @override
  String getAndroidDnsString() {
    final tag = _device.deviceTag!;
    final alias = _device.deviceAlias;
    return _check.getAndroidPrivateDnsString(Markers.root, tag, alias);
  }
}
