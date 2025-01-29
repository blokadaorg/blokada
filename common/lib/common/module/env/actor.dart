part of 'env.dart';

class EnvActor with Logging, Actor {
  late final _channel = Core.get<EnvChannel>();
  late final _userAgent = Core.get<UserAgent>();

  late final EnvInfo info;
  late final String deviceName;
  late final String userAgent;
  late final String appVersion;

  @override
  onStart(Marker m) async {
    info = await _channel.doGetEnvInfo();
    deviceName = info.deviceName;
    userAgent = _getUserAgent(info);
    await _userAgent.change(m, userAgent);
    appVersion = info.appVersion;
  }

  _getUserAgent(EnvInfo p) {
    return "blokada/${p.appVersion} (${Core.act.platform.name}-${p.osVersion} ${p.buildFlavor} ${p.buildType} ${p.cpu}) ${p.deviceBrand} ${p.deviceModel})";
  }
}
