import 'package:collection/collection.dart';
import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';

import '../../../util/cooldown.dart';
import '../../../util/mobx.dart';
import '../../account/account.dart';
import '../../device/device.dart';
import '../../stage/stage.dart';
import '../gateway/gateway.dart';
import '../keypair/keypair.dart';
import '../plus.dart';
import 'api.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'lease.g.dart';

extension JsonLeaseExt on JsonLease {
  Lease get toLease => Lease(
        accountId: accountId,
        publicKey: publicKey,
        gatewayId: gatewayId,
        expires: expires,
        alias: alias,
        vip4: vip4,
        vip6: vip6,
      );
}

class NoCurrentLeaseException implements Exception {}

class PlusLeaseStore = PlusLeaseStoreBase with _$PlusLeaseStore;

abstract class PlusLeaseStoreBase with Store, Logging, Actor, Cooldown {
  late final _ops = Core.get<PlusLeaseOps>();
  late final _json = Core.get<PlusLeaseApi>();
  late final _gateway = Core.get<PlusGatewayStore>();
  late final _keypair = Core.get<PlusKeypairStore>();
  late final _plus = Core.get<PlusStore>();
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();
  late final _device = Core.get<DeviceStore>();

  PlusLeaseStoreBase() {
    _stage.addOnValue(routeChanged, onRouteChanged);

    reactionOnStore((_) => leaseChanges, (_) async {
      await _ops.doLeasesChanged(leases);
    });

    reactionOnStore((_) => currentLease, (_) async {
      await _ops.doCurrentLeaseChanged(currentLease);
    });
  }

  @override
  onRegister() {
    Core.register<PlusLeaseOps>(getOps());
    Core.register<PlusLeaseApi>(PlusLeaseApi());
    Core.register<PlusLeaseStore>(this as PlusLeaseStore);
  }

  @observable
  List<Lease> leases = [];

  @observable
  int leaseChanges = 0;

  @observable
  Lease? currentLease;

  @observable
  DateTime lastRefresh = DateTime(0);

  @action
  Future<void> fetch(Marker m, {bool noRetry = false}) async {
    return await log(m).trace("fetch", (m) async {
      final leases = await _json.getLeases(m, noRetry: noRetry);
      this.leases = leases.map((it) => it.toLease).toList();
      leaseChanges++;

      // Find and verify current lease
      final current = _findCurrentLease();
      currentLease = current;
      if (current != null) {
        try {
          await _gateway.selectGateway(current.gatewayId, m);
        } on Exception catch (_) {
          currentLease = null;
          log(m).i("current lease for unknown gateway, setting to null");
          await _plus.reactToPlusLost(m);
        }
      } else {
        await _gateway.selectGateway(null, m);
        log(m).i("current lease no longer available");
        await _plus.reactToPlusLost(m);
      }
      markCooldown();
    });
  }

  @action
  Future<void> newLease(GatewayId gatewayId, Marker m) async {
    return await log(m).trace("newLease", (m) async {
      try {
        await _json.postLease(gatewayId, m);
        await fetch(m);
        if (currentLease == null) {
          throw NoCurrentLeaseException();
        }
      } on TooManyLeasesException catch (e) {
        // Too many leases, try to remove one with the alias of current device
        // and the public key of current device
        try {
          final lease = leases.firstWhere((it) =>
              it.alias == _device.deviceAlias &&
              it.publicKey == _keypair.currentDevicePublicKey);
          await _json.deleteLease(
            JsonLeasePayload(
              publicKey: lease.publicKey,
              gatewayId: lease.gatewayId,
            ),
            m,
          );
          await _json.postLease(gatewayId, m);
          await fetch(m);
          if (currentLease == null) {
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

  @action
  Future<void> deleteLease(Lease lease, Marker m) async {
    return await log(m).trace("deleteLease", (m) async {
      await _json.deleteLease(
        JsonLeasePayload(
          publicKey: lease.publicKey,
          gatewayId: lease.gatewayId,
        ),
        m,
      );
      await fetch(m);
    });
  }

  @action
  Future<void> deleteLeaseById(String leasePublicKey, Marker m) async {
    return await log(m).trace("deleteLeaseById", (m) async {
      final lease = leases.firstWhere((it) => it.publicKey == leasePublicKey);
      return deleteLease(lease, m);
    });
  }

  @action
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
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
    return leases.firstWhereOrNull(
        (it) => it.publicKey == _keypair.currentDevicePublicKey);
  }
}
