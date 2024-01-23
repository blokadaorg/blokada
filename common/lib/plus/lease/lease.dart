import 'package:collection/collection.dart';
import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../env/env.dart';
import '../../stage/stage.dart';
import '../../util/config.dart';
import '../../util/cooldown.dart';
import '../../util/di.dart';
import '../../util/mobx.dart';
import '../../util/trace.dart';
import '../gateway/gateway.dart';
import '../keypair/keypair.dart';
import '../plus.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

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

abstract class PlusLeaseStoreBase with Store, Traceable, Dependable, Cooldown {
  late final _ops = dep<PlusLeaseOps>();
  late final _json = dep<PlusLeaseJson>();
  late final _env = dep<EnvStore>();
  late final _gateway = dep<PlusGatewayStore>();
  late final _keypair = dep<PlusKeypairStore>();
  late final _plus = dep<PlusStore>();
  late final _stage = dep<StageStore>();
  late final _account = dep<AccountStore>();

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
  attach(Act act) {
    depend<PlusLeaseOps>(getOps(act));
    depend<PlusLeaseJson>(PlusLeaseJson());
    depend<PlusLeaseStore>(this as PlusLeaseStore);
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
  Future<void> fetch(Trace parentTrace, {bool noRetry = false}) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      final leases = await _json.getLeases(trace, noRetry: noRetry);
      this.leases = leases.map((it) => it.toLease).toList();
      leaseChanges++;

      // Find and verify current lease
      final current = _findCurrentLease();
      currentLease = current;
      if (current != null) {
        try {
          await _gateway.selectGateway(trace, current.gatewayId);
        } on Exception catch (_) {
          currentLease = null;
          trace.addEvent("current lease for unknown gateway, setting to null");
          await _plus.reactToPlusLost(trace);
        }
      } else {
        await _gateway.selectGateway(trace, null);
        trace.addEvent("current lease no longer available");
        await _plus.reactToPlusLost(trace);
      }
      markCooldown();
    });
  }

  @action
  Future<void> newLease(Trace parentTrace, GatewayId gatewayId) async {
    return await traceWith(parentTrace, "newLease", (trace) async {
      try {
        await _json.postLease(trace, gatewayId);
        await fetch(trace);
        if (currentLease == null) {
          throw NoCurrentLeaseException();
        }
      } on TooManyLeasesException catch (e) {
        // Too many leases, try to remove one with the alias of current device
        // and the public key of current device
        try {
          final lease = leases.firstWhere((it) =>
              it.alias == _env.deviceName &&
              it.publicKey == _keypair.currentDevicePublicKey);
          await _json.deleteLease(
            trace,
            JsonLeasePayload(
              accountId: lease.accountId,
              publicKey: lease.publicKey,
              gatewayId: lease.gatewayId,
            ),
          );
          await _json.postLease(trace, gatewayId);
          await fetch(trace);
          if (currentLease == null) {
            throw NoCurrentLeaseException();
          }
          trace.addEvent("deleted existing lease for current device alias");
        } catch (_) {
          // Rethrow the initial exception for clarity
          throw e;
        }
      }
    });
  }

  @action
  Future<void> deleteLease(Trace parentTrace, Lease lease) async {
    return await traceWith(parentTrace, "deleteLease", (trace) async {
      await _json.deleteLease(
        trace,
        JsonLeasePayload(
          accountId: lease.accountId,
          publicKey: lease.publicKey,
          gatewayId: lease.gatewayId,
        ),
      );
      await fetch(trace);
    });
  }

  @action
  Future<void> deleteLeaseById(Trace parentTrace, String leasePublicKey) async {
    return await traceWith(parentTrace, "deleteLeaseById", (trace) async {
      final lease = leases.firstWhere((it) => it.publicKey == leasePublicKey);
      return deleteLease(trace, lease);
    });
  }

  @action
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (_account.type != AccountType.plus) return;

    // Case one: refresh when entering the Settings tab (to see devices)
    if (route.isBecameTab(StageTab.settings) &&
        isCooledDown(cfg.plusLeaseRefreshCooldown)) {
      return await traceWith(parentTrace, "fetchLeasesSettings", (trace) async {
        await fetch(trace);
      });
    }

    // Case two: refresh when entering foreground but not too often
    if (!route.isBecameForeground()) return;
    if (!isCooledDown(cfg.plusLeaseRefreshCooldown)) return;

    return await traceWith(parentTrace, "fetchLeases", (trace) async {
      await fetch(trace);
    });
  }

  Lease? _findCurrentLease() {
    return leases.firstWhereOrNull(
        (it) => it.publicKey == _keypair.currentDevicePublicKey);
  }
}
