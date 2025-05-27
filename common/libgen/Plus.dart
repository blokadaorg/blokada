import 'package:pigeon/pigeon.dart';

class OpsGateway {
  final String publicKey;
  final String region;
  final String location;
  final int resourceUsagePercent;
  final String ipv4;
  final String ipv6;
  final int port;
  final String? country;

  OpsGateway(this.publicKey, this.region, this.location,
      this.resourceUsagePercent, this.ipv4, this.ipv6, this.port, this.country);
}

class OpsKeypair {
  late String publicKey;
  late String privateKey;
}

class OpsLease {
  late String accountId;
  late String publicKey;
  late String gatewayId;
  late String expires;
  late String? alias;
  late String vip4;
  late String vip6;
}

class OpsVpnConfig {
  late String devicePrivateKey;
  late String deviceTag;
  late String gatewayPublicKey;
  late String gatewayNiceName;
  late String gatewayIpv4;
  late String gatewayIpv6;
  late String gatewayPort;
  late String leaseVip4;
  late String leaseVip6;
  late List<String?> bypassedPackages;
}

class OpsInstalledApp {
  late String packageName;
  late String appName;
}

@HostApi()
abstract class PlusOps {
  // Keypair

  @async
  OpsKeypair doGenerateKeypair();

  // Gateway

  @async
  void doGatewaysChanged(List<OpsGateway> gateways);

  @async
  void doSelectedGatewayChanged(String? publicKey);

  // Lease

  @async
  void doLeasesChanged(List<OpsLease> leases);

  @async
  void doCurrentLeaseChanged(OpsLease? lease);

  // VPN

  @async
  void doSetVpnConfig(OpsVpnConfig config);

  @async
  void doSetVpnActive(bool active);

  // Plus

  @async
  void doPlusEnabledChanged(bool plusEnabled);

  // Bypass

  @async
  List<OpsInstalledApp> doGetInstalledApps();

  @async
  Uint8List? doGetAppIcon(String packageName);
}

@FlutterApi()
abstract class PlusVpnEvents {
  @async
  void onVpnStatus(String status);
}
