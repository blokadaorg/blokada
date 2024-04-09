import 'package:common/dragon/device/this_device.dart';
import 'package:common/dragon/perm/dns_perm.dart';
import 'package:common/perm/channel.pg.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';

class PermController with Traceable {
  late final _ops = dep<PermOps>();
  late final _perm = dep<DnsPerm>();
  late final _deviceTag = dep<ThisDevice>();

  late final _stage = dep<StageStore>();

  start() async {
    _check();
    _deviceTag.onChange.listen((it) => _check());
    _stage.addOnValue(routeChanged, onRouteChanged);
  }

  _check() async {
    final device = await _deviceTag.fetch();
    if (device == null) {
      _perm.now = false;
      return;
    }
    await _ops.doSetDns(device.deviceTag);
    _perm.now = await _ops.doIsPrivateDnsEnabled(device.deviceTag);
  }

  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (!(route.isBecameForeground() || route.modal == StageModal.perms)) {
      return;
    }

    return await traceWith(parentTrace, "permCheck", (trace) async {
      await _check();
    });
  }
}
