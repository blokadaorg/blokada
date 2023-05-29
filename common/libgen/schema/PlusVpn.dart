import 'package:pigeon/pigeon.dart';

// enum VpnStatus {
//   unknown,
//   initializing,
//   reconfiguring,
//   deactivated,
//   paused,
//   activated
// }

class VpnConfig {
  late String devicePrivateKey;
  late String deviceTag;
  late String gatewayPublicKey;
  late String gatewayNiceName;
  late String gatewayIpv4;
  late String gatewayIpv6;
  late String gatewayPort;
  late String leaseVip4;
  late String leaseVip6;
}

@HostApi()
abstract class PlusVpnOps {
  @async
  void doSetVpnConfig(VpnConfig config);

  @async
  void doSetVpnActive(bool active);
}

@FlutterApi()
abstract class PlusVpnEvents {
  @async
  void onVpnStatus(String status);
}
