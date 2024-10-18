import 'package:common/common/model.dart';
import 'package:common/logger/logger.dart';
import 'package:common/util/di.dart';

class PrivateDnsCheck with Dependable, Logging {
  @override
  void attach(Act act) {
    depend<PrivateDnsCheck>(this);
  }

  bool isCorrect(Marker m, String line, DeviceTag tag, String alias) {
    log(m).pair("current dns", line);

    var expected = _getIosPrivateDnsStringV6(m, tag, alias);

    if (act.getPlatform() == Platform.android) {
      expected = getAndroidPrivateDnsString(m, tag, alias);
    } else if (act.getFlavor() == Flavor.family) {
      expected = _getIosPrivateDnsStringFamily(m, tag, alias);
    }

    return line == expected;
  }

  String _getIosPrivateDnsStringV6(Marker m, DeviceTag tag, String alias) {
    try {
      final name = _escapeAlias(alias);
      return "https://cloud.blokada.org/$tag/$name";
    } catch (e) {
      log(m).e(msg: "getIosPrivatDnsString", err: e);
      return "";
    }
  }

  String _getIosPrivateDnsStringFamily(Marker m, DeviceTag tag, String alias) {
    try {
      final name = _escapeAlias(alias);
      return "https://cloud.blokada.org/$tag/$name";
    } catch (e) {
      log(m).e(msg: "getIosPrivatDnsString", err: e);
      return "";
    }
  }

  String getAndroidPrivateDnsString(Marker m, DeviceTag tag, String alias) {
    try {
      final name = _sanitizeAlias(alias);
      return "$name-$tag.cloud.blokada.org";
    } catch (e) {
      log(m).e(msg: "getAndroidPrivateDnsString", err: e);
      return "";
    }
  }

  String _sanitizeAlias(String alias) {
    var a = alias.trim().replaceAll(" ", "--");
    if (a.length > 56) a = a.substring(0, 56);
    return a;
  }

  String _escapeAlias(String alias) {
    // TODO: implement
    return alias.trim();
  }
}
