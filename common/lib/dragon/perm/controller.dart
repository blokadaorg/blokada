import 'package:common/core/core.dart';
import 'package:common/dragon/device/this_device.dart';
import 'package:common/dragon/perm/dns_perm.dart';
import 'package:common/platform/perm/channel.pg.dart';
import 'package:common/platform/perm/dnscheck.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';

class PermController with Logging {
  late final _ops = dep<PermOps>();
  late final _perm = dep<DnsPerm>();
  late final _deviceTag = dep<ThisDevice>();
  late final _act = dep<Act>();
  late final _check = dep<PrivateDnsCheck>();

  late final _stage = dep<StageStore>();

  start(Marker m) async {
    _checkDns(m);
    _deviceTag.onChange.listen((it) => _checkDns(m));
    _stage.addOnValue(routeChanged, onRouteChanged);
  }

  _checkDns(Marker m) async {
    final device = await _deviceTag.fetch();
    if (device == null) {
      _perm.now = false;
      return;
    }
    await _ops.doSetDns(device.deviceTag);

    final current = await _ops.getPrivateDnsSetting();
    _perm.now = _check.isCorrect(m, current, device.deviceTag, device.alias);
  }

  String getAndroidDnsStringToCopy(Marker m) {
    final tag = _deviceTag.now!.deviceTag;
    final alias = _deviceTag.now!.alias;
    return _check.getAndroidPrivateDnsString(m, tag, alias);
  }

  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!(route.isBecameForeground() || route.modal == StageModal.perms)) {
      log(m).pair("permIsBecameForeground", route.isBecameForeground());
      log(m).pair("permIsForeground", route.isForeground());
      return;
    }

    await _checkDns(m);
  }
}
