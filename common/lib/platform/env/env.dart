import 'package:common/common/api/api.dart';
import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';

import '../../util/mobx.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'env.g.dart';

class EnvStore = EnvStoreBase with _$EnvStore;

extension on EnvPayload {
  toSimpleString() {
    return "appVersion: $appVersion, "
        "osVersion: $osVersion, "
        "buildFlavor: $buildFlavor, "
        "buildType: $buildType, "
        "cpu: $cpu, "
        "deviceBrand: $deviceBrand, "
        "deviceModel: $deviceModel, "
        "deviceName: $deviceName";
  }
}

abstract class EnvStoreBase with Store, Logging, Actor {
  late final _ops = Core.get<EnvOps>();
  late final _agent = Core.get<UserAgent>();

  EnvStoreBase() {
    reactionOnStore((_) => userAgent, (_) async {
      final ua = userAgent;
      if (ua == null) return;
      await _ops.doUserAgentChanged(ua);
    });
  }

  @override
  onRegister() {
    Core.register<EnvOps>(getOps());
    Core.register<EnvStore>(this as EnvStore);
  }

  @observable
  // OS provided device name, can be generic like "iPhone"
  String? deviceName;

  @observable
  String? userAgent;

  @observable
  String? appVersion;

  @override
  Future<void> onStart(Marker m) async {
    return await log(m).trace("startEnv", (m) async {
      await syncUserAgent(m);
    });
  }

  @action
  Future<void> syncUserAgent(Marker m) async {
    return await log(m).trace("syncUserAgent", (m) async {
      final payload = await _ops.doGetEnvPayload();
      deviceName = payload.deviceName;
      userAgent = _getUserAgent(payload);
      appVersion = payload.appVersion;
      _agent.change(m, userAgent!);
      log(m).pair("device", payload.toSimpleString());
    });
  }

  _getUserAgent(EnvPayload p) {
    return "blokada/${p.appVersion} (${Core.act.platform.name}-${p.osVersion} ${p.buildFlavor} ${p.buildType} ${p.cpu}) ${p.deviceBrand} ${p.deviceModel})";
  }
}
