import 'package:collection/collection.dart';
import 'package:mobx/mobx.dart';

import '../../persistence/persistence.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../util/config.dart';
import '../../util/cooldown.dart';
import '../../util/di.dart';
import '../../util/mobx.dart';
import '../../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'gateway.g.dart';

extension GatewayExt on Gateway {
  // Location with capitalized each word
  String get niceName => location
      .split("-")
      .map((it) => it[0].toUpperCase() + it.substring(1))
      .join(" ");
}

extension JsonGatewayExt on JsonGateway {
  Gateway get toGateway => Gateway(
        publicKey: publicKey,
        region: region,
        location: location,
        resourceUsagePercent: resourceUsagePercent,
        ipv4: ipv4,
        ipv6: ipv6,
        port: port,
        country: country,
      );
}

const String _keySelected = "gateway:jsonSelectedGateway";

typedef GatewayId = String;

class PlusGatewayStore = PlusGatewayStoreBase with _$PlusGatewayStore;

abstract class PlusGatewayStoreBase
    with Store, Traceable, Dependable, Cooldown {
  late final _ops = dep<PlusGatewayOps>();
  late final _json = dep<PlusGatewayJson>();
  late final _persistence = dep<PersistenceService>();
  late final _stage = dep<StageStore>();

  PlusGatewayStoreBase() {
    _stage.addOnValue(routeChanged, onRouteChanged);

    reactionOnStore((_) => gatewayChanges, (_) async {
      await _ops.doGatewaysChanged(gateways);
    });

    reactionOnStore((_) => currentGateway, (gateway) async {
      await _ops.doSelectedGatewayChanged(gateway?.publicKey);
    });
  }

  @override
  attach(Act act) {
    depend<PlusGatewayOps>(getOps(act));
    depend<PlusGatewayJson>(PlusGatewayJson());
    depend<PlusGatewayStore>(this as PlusGatewayStore);
  }

  @observable
  List<Gateway> gateways = [];

  @observable
  int gatewayChanges = 0;

  @observable
  Gateway? currentGateway;

  @action
  Future<void> fetch(Trace parentTrace) async {
    return await traceWith(parentTrace, "fetch", (trace) async {
      try {
        final gateways = await _json.get(trace);
        this.gateways = gateways.map((it) => it.toGateway).toList();
        gatewayChanges++;
      } catch (e) {
        // Always emit gateways so the UI displays it
        gatewayChanges++;
      }
    });
  }

  @action
  Future<void> load(Trace parentTrace) async {
    return await traceWith(parentTrace, "load", (trace) async {
      final id = await _persistence.load(trace, _keySelected);
      currentGateway = gateways.firstWhereOrNull((it) => it.publicKey == id);
      trace.addAttribute("currentGateway", currentGateway);
    });
  }

  @action
  Future<void> selectGateway(Trace parentTrace, GatewayId? id) async {
    return await traceWith(parentTrace, "selectGateway", (trace) async {
      if (id == null) {
        currentGateway = null;
        await _persistence.delete(trace, _keySelected);
        return;
      }

      try {
        final gateway = gateways.firstWhere((it) => it.publicKey == id);
        currentGateway = gateway;
        await _persistence.saveString(trace, _keySelected, id);
        trace.addAttribute("selectedGateway", gateway.location);
      } on StateError catch (_) {
        throw Exception("Unknown gateway: $id");
      }
    });
  }

  @action
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (route.isModal(StageModal.plusLocationSelect)) {
      return await traceWith(parentTrace, "fetchGatewaysOnModal",
          (trace) async {
        await fetch(trace);
      });
    }

    if (!route.isBecameForeground()) return;
    if (!isCooledDown(cfg.plusGatewayRefreshCooldown)) return;

    return await traceWith(parentTrace, "fetchGateways", (trace) async {
      await fetch(trace);
    });
  }
}
