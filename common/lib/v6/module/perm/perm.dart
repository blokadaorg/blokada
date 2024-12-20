import 'package:common/core/core.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/perm/dnscheck.dart';
import 'package:common/platform/perm/perm.dart';

class V6PermModule with Module {
  @override
  onCreateModule() async {
    await register<PrivateDnsStringProvider>(V6PrivateDnsStringProvider());
  }
}

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
