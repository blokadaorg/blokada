import 'package:pigeon/pigeon.dart';

class Gateway {
  final String publicKey;
  final String region;
  final String location;
  final int resourceUsagePercent;
  final String ipv4;
  final String ipv6;
  final int port;
  final String? country;

  Gateway(this.publicKey, this.region, this.location, this.resourceUsagePercent,
      this.ipv4, this.ipv6, this.port, this.country);
}

@HostApi()
abstract class PlusGatewayOps {
  @async
  void doGatewaysChanged(List<Gateway> gateways);

  @async
  void doSelectedGatewayChanged(String? publicKey);
}
