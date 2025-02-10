part of 'lease.dart';

class LeaseActor with Logging, Actor, Cooldown {
  late final _channel = Core.get<LeaseChannel>();
  late final _api = Core.get<LeaseApi>();
  late final _keypair = Core.get<CurrentKeypairValue>();
  late final _gateway = Core.get<GatewayActor>();
  late final _currentLease = Core.get<CurrentLeaseValue>();

  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();
  late final _device = Core.get<DeviceStore>();

  List<Lease> leases = [];

  DateTime lastRefresh = DateTime(0);

  @override
  onStart(Marker m) async {
    _stage.addOnValue(routeChanged, onRouteChanged);

    _currentLease.onChange.listen((_) {
      _channel.doCurrentLeaseChanged(_currentLease.present);
    });
  }

  fetch(Marker m, {bool noRetry = false}) async {
    return await log(m).trace("fetch", (m) async {
      final leases = await _api.getLeases(m, noRetry: noRetry);
      this.leases = leases.map((it) => it.toLease).toList();
      _channel.doLeasesChanged(this.leases);

      // Find and verify current lease
      final current = _findCurrentLease();
      await _currentLease.change(m, current);
      if (current != null) {
        try {
          await _gateway.selectGateway(current.gatewayId, m);
        } on Exception catch (_) {
          log(m).i("current lease for unknown gateway, setting to null");
          await _currentLease.change(m, null);
        }
      } else {
        await _gateway.selectGateway(null, m);
        log(m).i("current lease no longer available");
      }
      markCooldown();
    });
  }

  newLease(GatewayId gatewayId, Marker m) async {
    return await log(m).trace("newLease", (m) async {
      final keypairPk = _keypair.present!.publicKey;
      final deviceAlias = _device.deviceAlias;

      try {
        await _api.postLease(m, deviceAlias, keypairPk, gatewayId);
        await fetch(m);
        if (_currentLease.present == null) {
          throw NoCurrentLeaseException();
        }
      } on TooManyLeasesException catch (e) {
        // Too many leases, try to remove one with the alias of current device
        // and the public key of current device
        try {
          final lease = leases.firstWhere(
              (it) => it.alias == deviceAlias && it.publicKey == keypairPk);
          await _api.deleteLease(
            JsonLeasePayload(
              publicKey: lease.publicKey,
              gatewayId: lease.gatewayId,
            ),
            m,
          );
          await _api.postLease(m, deviceAlias, keypairPk, gatewayId);
          await fetch(m);
          if (_currentLease.present == null) {
            throw NoCurrentLeaseException();
          }
          log(m).i("deleted existing lease for current device alias");
        } catch (_) {
          // Rethrow the initial exception for clarity
          throw e;
        }
      }
    });
  }

  deleteLease(Lease lease, Marker m) async {
    return await log(m).trace("deleteLease", (m) async {
      await _api.deleteLease(
        JsonLeasePayload(
          publicKey: lease.publicKey,
          gatewayId: lease.gatewayId,
        ),
        m,
      );
      await fetch(m);
    });
  }

  deleteLeaseById(String leasePublicKey, Marker m) async {
    return await log(m).trace("deleteLeaseById", (m) async {
      final lease = leases.firstWhere((it) => it.publicKey == leasePublicKey);
      return deleteLease(lease, m);
    });
  }

  onRouteChanged(StageRouteState route, Marker m) async {
    if (_account.type != AccountType.plus) return;

    // Case one: refresh when entering the Settings tab (to see devices)
    if (route.isBecameTab(StageTab.settings) &&
        isCooledDown(Core.config.plusLeaseRefreshCooldown)) {
      return await log(m).trace("fetchLeasesSettings", (m) async {
        await fetch(m);
      });
    }

    // Case two: refresh when entering foreground but not too often
    if (!route.isBecameForeground()) return;
    if (!isCooledDown(Core.config.plusLeaseRefreshCooldown)) return;

    return await log(m).trace("fetchLeases", (m) async {
      await fetch(m);
    });
  }

  Lease? _findCurrentLease() {
    return leases
        .firstWhereOrNull((it) => it.publicKey == _keypair.present!.publicKey);
  }
}
