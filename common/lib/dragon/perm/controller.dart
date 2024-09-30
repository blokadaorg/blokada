import 'package:common/dragon/device/this_device.dart';
import 'package:common/dragon/perm/dns_perm.dart';
import 'package:common/logger/logger.dart';
import 'package:common/perm/channel.pg.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';

class PermController with Logging {
  late final _ops = dep<PermOps>();
  late final _perm = dep<DnsPerm>();
  late final _deviceTag = dep<ThisDevice>();
  late final _act = dep<Act>();

  late final _stage = dep<StageStore>();

  start(Marker m) async {
    _check(m);
    _deviceTag.onChange.listen((it) => _check(m));
    _stage.addOnValue(routeChanged, onRouteChanged);
  }

  String getAndroidPrivateDnsString(Marker m) {
    try {
      final device = _deviceTag.now!;
      final name = _sanitizeAlias(device.alias);
      final tag = device.deviceTag;
      return "$name-$tag.cloud.blokada.org";
    } catch (e) {
      log(m).e(msg: "getAndroidPrivateDnsString", err: e);
      return "";
    }
  }

  _sanitizeAlias(String alias) {
    var a = alias.trim().replaceAll(" ", "--");
    if (a.length > 56) a = a.substring(0, 56);
    return a;
  }

  _check(Marker m) async {
    final device = await _deviceTag.fetch();
    if (device == null) {
      _perm.now = false;
      return;
    }
    await _ops.doSetDns(device.deviceTag);

    // TODO: do this for both platforms eventually
    if (_act.getPlatform() == Platform.android) {
      final current = await _ops.getPrivateDnsSetting();
      _perm.now = current == getAndroidPrivateDnsString(m);
    } else {
      _perm.now = await _ops.doIsPrivateDnsEnabled(device.deviceTag);
    }
  }

  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!(route.isBecameForeground() || route.modal == StageModal.perms)) {
      log(m).pair("permIsBecameForeground", route.isBecameForeground());
      log(m).pair("permIsForeground", route.isForeground());
      return;
    }

    await _check(m);
  }
}
