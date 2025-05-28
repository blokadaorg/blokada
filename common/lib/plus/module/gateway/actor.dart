part of 'gateway.dart';

class GatewayActor with Logging, Actor, Cooldown {
  late final _stage = Core.get<StageStore>();

  late final _channel = Core.get<GatewayChannel>();
  late final _api = Core.get<GatewayApi>();
  late final _currentGatewayId = Core.get<CurrentGatewayIdValue>();
  late final _currentGateway = Core.get<CurrentGatewayValue>();
  late final _gateways = Core.get<GatewaysValue>();

  @override
  onStart(Marker m) async {
    _stage.addOnValue(routeChanged, onRouteChanged);
  }

  fetch(Marker m) async {
    return await log(m).trace("fetch", (m) async {
      List<Gateway> gateways = [];
      try {
        final jsonGateways = await _api.get(m);
        gateways = jsonGateways.map((it) => it.toGateway).toList();
        _gateways.change(m, gateways);
        _channel.doGatewaysChanged(gateways);
      } catch (e) {
        // Always emit gateways so the UI displays it
        _channel.doGatewaysChanged(gateways);
      }
      markCooldown();
    });
  }

  load(Marker m) async {
    return await log(m).trace("load", (m) async {
      var id = await _currentGatewayId.fetch(m);
      if (id?.isBlank ?? false) id = null; // Not sure why, but it happened

      await fetch(m);
      await selectGateway(id, m);
    });
  }

  selectGateway(GatewayId? id, Marker m) async {
    return await log(m).trace("selectGateway", (m) async {
      if (id == null) {
        await _currentGatewayId.change(m, null);
        await _currentGateway.change(m, null);
        _channel.doSelectedGatewayChanged(null);
        return;
      }

      try {
        final gateway =
            (await _gateways.now())!.firstWhere((it) => it.publicKey == id);
        await _currentGatewayId.change(m, id);
        await _currentGateway.change(m, gateway);
        _channel.doSelectedGatewayChanged(id);
        log(m).pair("selectedGateway", gateway.location);
      } on StateError catch (_) {
        throw Exception("Unknown gateway: $id");
      }
    });
  }

  onRouteChanged(StageRouteState route, Marker m) async {
    if (route.isModal(StageModal.plusLocationSelect)) {
      return await log(m).trace("fetchGatewaysOnModal", (m) async {
        await fetch(m);
      });
    }

    if (!route.isBecameForeground()) return;
    if (!isCooledDown(Core.config.plusGatewayRefreshCooldown)) return;

    return await log(m).trace("fetchGateways", (m) async {
      await fetch(m);
    });
  }
}
