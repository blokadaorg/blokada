import 'package:collection/collection.dart';
import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';

import '../../../util/cooldown.dart';
import '../../../util/mobx.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
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

abstract class PlusGatewayStoreBase with Store, Logging, Actor, Cooldown {
  late final _ops = DI.get<PlusGatewayOps>();
  late final _json = DI.get<PlusGatewayJson>();
  late final _persistence = DI.get<Persistence>();
  late final _stage = DI.get<StageStore>();

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
  onRegister(Act act) {
    DI.register<PlusGatewayOps>(getOps(act));
    DI.register<PlusGatewayJson>(PlusGatewayJson());
    DI.register<PlusGatewayStore>(this as PlusGatewayStore);
  }

  @observable
  List<Gateway> gateways = [];

  @observable
  int gatewayChanges = 0;

  @observable
  Gateway? currentGateway;

  @action
  Future<void> fetch(Marker m) async {
    return await log(m).trace("fetch", (m) async {
      try {
        final gateways = await _json.get(m);
        this.gateways = gateways.map((it) => it.toGateway).toList();
        gatewayChanges++;
      } catch (e) {
        // Always emit gateways so the UI displays it
        gatewayChanges++;
      }
      markCooldown();
    });
  }

  @action
  Future<void> load(Marker m) async {
    return await log(m).trace("load", (m) async {
      final id = await _persistence.load(_keySelected);
      currentGateway = gateways.firstWhereOrNull((it) => it.publicKey == id);
      log(m).pair("currentGateway", currentGateway);
    });
  }

  @action
  Future<void> selectGateway(GatewayId? id, Marker m) async {
    return await log(m).trace("selectGateway", (m) async {
      if (id == null) {
        currentGateway = null;
        await _persistence.delete(_keySelected);
        return;
      }

      try {
        final gateway = gateways.firstWhere((it) => it.publicKey == id);
        currentGateway = gateway;
        await _persistence.save(_keySelected, id);
        log(m).pair("selectedGateway", gateway.location);
      } on StateError catch (_) {
        throw Exception("Unknown gateway: $id");
      }
    });
  }

  @action
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (route.isModal(StageModal.plusLocationSelect)) {
      return await log(m).trace("fetchGatewaysOnModal", (m) async {
        await fetch(m);
      });
    }

    if (!route.isBecameForeground()) return;
    if (!isCooledDown(cfg.plusGatewayRefreshCooldown)) return;

    return await log(m).trace("fetchGateways", (m) async {
      await fetch(m);
    });
  }
}
