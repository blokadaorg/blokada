part of 'vpn.dart';

enum VpnStatus {
  unknown,
  initializing,
  reconfiguring,
  deactivated,
  paused,
  activated
}

extension VpnStatusExt on VpnStatus {
  isReady() =>
      this == VpnStatus.activated ||
      this == VpnStatus.paused ||
      this == VpnStatus.deactivated;
  isActive() => this == VpnStatus.activated;
}

extension on String {
  VpnStatus toVpnStatus() {
    switch (this) {
      case "initializing":
        return VpnStatus.initializing;
      case "reconfiguring":
        return VpnStatus.reconfiguring;
      case "deactivated":
        return VpnStatus.deactivated;
      case "paused":
        return VpnStatus.paused;
      case "activated":
        return VpnStatus.activated;
      default:
        return VpnStatus.unknown;
    }
  }
}

class VpnConfig {
  final String devicePrivateKey;
  final String deviceTag;
  final String gatewayPublicKey;
  final String gatewayNiceName;
  final String gatewayIpv4;
  final String gatewayIpv6;
  final String gatewayPort;
  final String leaseVip4;
  final String leaseVip6;
  final Set<String> bypassedPackages;

  VpnConfig({
    required this.devicePrivateKey,
    required this.deviceTag,
    required this.gatewayPublicKey,
    required this.gatewayNiceName,
    required this.gatewayIpv4,
    required this.gatewayIpv6,
    required this.gatewayPort,
    required this.leaseVip4,
    required this.leaseVip6,
    required this.bypassedPackages,
  });

  bool isSame(VpnConfig other) {
    return devicePrivateKey == other.devicePrivateKey &&
        deviceTag == other.deviceTag &&
        gatewayPublicKey == other.gatewayPublicKey &&
        gatewayNiceName == other.gatewayNiceName &&
        gatewayIpv4 == other.gatewayIpv4 &&
        gatewayIpv6 == other.gatewayIpv6 &&
        gatewayPort == other.gatewayPort &&
        leaseVip4 == other.leaseVip4 &&
        leaseVip6 == other.leaseVip6 &&
        const SetEquality().equals(bypassedPackages, other.bypassedPackages);
  }
}
