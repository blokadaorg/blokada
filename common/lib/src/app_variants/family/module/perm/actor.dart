part of 'perm.dart';

mixin PermChannel {
  Future<PrivateDnsState> getPrivateDnsState();
  Future<bool> isRunningOnMac();
  Future<void> doSetPrivateDnsEnabled(String tag, String alias);
  Future<void> doSetDns(String tag);
  Future<bool> doNotificationEnabled();
  Future<bool> doVpnEnabled();
  Future<void> doOpenPermSettings();
  Future<void> doAskNotificationPerms();
  Future<void> doAskVpnPerms();
  Future<bool> doAuthenticate();
}

class PermActor with Logging, Actor {
  late final _channel = Core.get<PermChannel>();
  late final _perm = Core.get<DnsPerm>();
  late final _deviceTag = Core.get<ThisDevice>();
  late final _check = Core.get<PrivateDnsCheck>();

  late final _stage = Core.get<StageStore>();

  @override
  onStart(Marker m) async {
    _checkDns(m);
    _deviceTag.onChange.listen((it) => _checkDns(m));
    _stage.addOnValue(routeChanged, onRouteChanged);
  }

  _checkDns(Marker m) async {
    final device = await _deviceTag.fetch(m);
    if (device == null) {
      await _perm.change(m, false);
      return;
    }
    await _channel.doSetDns(device.deviceTag);

    // Use API check on macOS, local check on iOS/iPadOS
    final isOnMac = await _channel.isRunningOnMac();
    if (isOnMac) {
      final isEnabled = await _check.checkPrivateDnsEnabledWithApi(m, device.deviceTag);
      await _perm.change(m, isEnabled);
    } else {
      final current = await _channel.getPrivateDnsState();
      final isEnabled = current.kind == PrivateDnsStateKind.enabled &&
          current.serverUrl != null &&
          _check.isCorrect(m, current.serverUrl!, device.deviceTag, device.alias);
      await _perm.change(m, isEnabled);
    }
  }

  String getAndroidDnsStringToCopy(Marker m) {
    final tag = _deviceTag.present!.deviceTag;
    final alias = _deviceTag.present!.alias;
    if (Core.act.flavor == Flavor.family) {
      return _check.getAndroidPrivateDnsStringFamily(m, tag);
    } else {
      return _check.getAndroidPrivateDnsString(m, tag, alias);
    }
  }

  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isBecameForeground()) {
      log(m).pair("permIsBecameForeground", route.isBecameForeground());
      log(m).pair("permIsForeground", route.isForeground());
      return;
    }

    await _checkDns(m);
  }
}
