import 'package:common/common/state/state.dart';
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

abstract class EnvStoreBase with Store, Logging, Dependable, Startable {
  late final _ops = dep<EnvOps>();
  late final _agent = dep<UserAgent>();

  EnvStoreBase() {
    reactionOnStore((_) => userAgent, (_) async {
      final ua = userAgent;
      if (ua == null) return;
      await _ops.doUserAgentChanged(ua);
    });
  }

  @override
  attach(Act act) {
    depend<EnvOps>(getOps(act));
    depend<EnvStore>(this as EnvStore);
  }

  @observable
  // OS provided device name, can be generic like "iPhone"
  String? deviceName;

  @observable
  String? userAgent;

  @observable
  String? appVersion;

  @override
  @action
  Future<void> start(Marker m) async {
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
      _agent.now = userAgent!;
      log(m).pair("device", payload.toSimpleString());
    });
  }

  _getUserAgent(EnvPayload p) {
    return "blokada/${p.appVersion} (${act.getPlatform().name}-${p.osVersion} ${p.buildFlavor} ${p.buildType} ${p.cpu}) ${p.deviceBrand} ${p.deviceModel})";
  }
}
