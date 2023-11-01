import 'package:mobx/mobx.dart';

import '../util/di.dart';
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

  @override
  attach(Act act) {
    depend<EnvOps>(getOps(act));
    depend<EnvStore>(this as EnvStore);
  }

  @observable
  // OS provided device name, can be generic like "iPhone"
  String? deviceName;

  @override
  @action
  Future<void> start(Trace parentTrace) async {
    return await traceWith(parentTrace, "start", (trace) async {
      await syncDeviceName(trace);
    });
  }

  @action
  Future<void> syncDeviceName(Trace parentTrace) async {
    return await traceWith(parentTrace, "setDeviceName", (trace) async {
      final payload = await _ops.doGetEnvPayload();
      deviceName = payload.deviceName;
      trace.addAttribute("device", payload.toSimpleString());
    });
  }
}
