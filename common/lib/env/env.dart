import 'package:mobx/mobx.dart';

import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
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

abstract class EnvStoreBase with Store, Traceable, Dependable, Startable {
  late final _ops = dep<EnvOps>();

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

  @override
  @action
  Future<void> start(Trace parentTrace) async {
    return await traceWith(parentTrace, "start", (trace) async {
      await syncUserAgent(trace);
    });
  }

  @action
  Future<void> syncUserAgent(Trace parentTrace) async {
    return await traceWith(parentTrace, "syncUserAgent", (trace) async {
      final payload = await _ops.doGetEnvPayload();
      deviceName = payload.deviceName;
      userAgent = _getUserAgent(payload);
      trace.addAttribute("device", payload.toSimpleString());
    });
  }

  _getUserAgent(EnvPayload p) {
    return "blokada/${p.appVersion} (${act.getPlatform().name}-${p.osVersion} ${p.buildFlavor} ${p.buildType} ${p.cpu}) ${p.deviceBrand} ${p.deviceModel})";
  }
}
