part of 'plus.dart';

class PlatformPlusChannel extends PlusChannel {
  late final _ops = PlusOps();

  // Keypair

  @override
  Future<Keypair> doGenerateKeypair() async {
    final kp = await _ops.doGenerateKeypair();
    return Keypair(
      publicKey: kp.publicKey,
      privateKey: kp.privateKey,
    );
  }

  // Gateway

  @override
  Future<void> doGatewaysChanged(List<Gateway> gateways) =>
      _ops.doGatewaysChanged(
        gateways
            .map((g) => OpsGateway(
                  publicKey: g.publicKey,
                  region: g.region,
                  location: g.location,
                  resourceUsagePercent: g.resourceUsagePercent,
                  ipv4: g.ipv4,
                  ipv6: g.ipv6,
                  port: g.port,
                  country: g.country,
                ))
            .toList(),
      );

  @override
  Future<void> doSelectedGatewayChanged(GatewayId? publicKey) =>
      _ops.doSelectedGatewayChanged(
        publicKey,
      );

  // Lease

  @override
  Future<void> doLeasesChanged(List<Lease> leases) => _ops.doLeasesChanged(
        leases
            .map((l) => OpsLease(
                  accountId: l.accountId,
                  publicKey: l.publicKey,
                  gatewayId: l.gatewayId,
                  expires: l.expires,
                  alias: l.alias,
                  vip4: l.vip4,
                  vip6: l.vip6,
                ))
            .toList(),
      );

  @override
  Future<void> doCurrentLeaseChanged(Lease? lease) =>
      _ops.doCurrentLeaseChanged(
        lease != null
            ? OpsLease(
                accountId: lease.accountId,
                publicKey: lease.publicKey,
                gatewayId: lease.gatewayId,
                expires: lease.expires,
                alias: lease.alias,
                vip4: lease.vip4,
                vip6: lease.vip6,
              )
            : null,
      );

  // VPN

  @override
  Future<void> doSetVpnConfig(VpnConfig config) => _ops.doSetVpnConfig(
        OpsVpnConfig(
          devicePrivateKey: config.devicePrivateKey,
          deviceTag: config.deviceTag,
          gatewayPublicKey: config.gatewayPublicKey,
          gatewayNiceName: config.gatewayNiceName,
          gatewayIpv4: config.gatewayIpv4,
          gatewayIpv6: config.gatewayIpv6,
          gatewayPort: config.gatewayPort,
          leaseVip4: config.leaseVip4,
          leaseVip6: config.leaseVip6,
          bypassedPackages: config.bypassedPackages.toList(),
        ),
      );

  @override
  Future<void> doSetVpnActive(bool active) => _ops.doSetVpnActive(active);

  @override
  Future<void> doPlusEnabledChanged(bool plusEnabled) =>
      _ops.doPlusEnabledChanged(plusEnabled);

  // Bypass

  @override
  Future<List<InstalledApp>> doGetInstalledApps() => _ops
      .doGetInstalledApps()
      .then(
        (apps) => apps
            .map((app) => InstalledApp.fromOps(app!.packageName, app.appName))
            .toList(),
      );

  @override
  Future<Uint8List?> doGetAppIcon(String packageName) =>
      _ops.doGetAppIcon(packageName);
}

class NoOpPlusChannel extends PlusChannel {
  // Keypair

  @override
  Future<Keypair> doGenerateKeypair() =>
      Future.value(Keypair(publicKey: 'mock-pk', privateKey: 'mock-sk'));

  // Gateway

  @override
  Future<void> doGatewaysChanged(List<Gateway> gateways) => Future.value();

  @override
  Future<void> doSelectedGatewayChanged(GatewayId? publicKey) => Future.value();

  // Lease

  @override
  Future<void> doLeasesChanged(List<Lease> leases) => Future.value();

  @override
  Future<void> doCurrentLeaseChanged(Lease? lease) => Future.value();

  // VPN

  @override
  Future<void> doSetVpnConfig(VpnConfig config) => Future.value();

  @override
  Future<void> doSetVpnActive(bool active) => Future.value();

  @override
  Future<void> doPlusEnabledChanged(bool plusEnabled) => Future.value();

  // Bypass

  @override
  Future<List<InstalledApp>> doGetInstalledApps() => Future.value(
        [
          InstalledApp(
            packageName: 'com.example.app',
            appName: 'Example App',
          ),
        ],
      );

  @override
  Future<Uint8List?> doGetAppIcon(String packageName) => Future.value();
}

final fixtureVpnConfig = VpnConfig(
  devicePrivateKey: 'devicePrivateKey',
  deviceTag: 'deviceTag',
  gatewayPublicKey: 'gatewayPublicKey',
  gatewayNiceName: 'gatewayNiceName',
  gatewayIpv4: 'gatewayIpv4',
  gatewayIpv6: 'gatewayIpv6',
  gatewayPort: 'gatewayPort',
  leaseVip4: 'leaseVip4',
  leaseVip6: 'leaseVip6',
  bypassedPackages: {},
);
