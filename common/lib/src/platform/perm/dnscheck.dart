import 'dart:convert';

import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:dartx/dartx.dart';

/// Whether the `flavor` reported by `v3/status/test` belongs to Blokada 6.
/// Family's own DNS reports `family`; only the v6 flavors (cloud/plus) mean
/// Family should defer. Kept here so both the Family phase mapper and the perm
/// actor share one definition of "v6 owns DNS".
bool isBlokadaSixDnsFlavor(String? flavor) =>
    flavor == AccountType.cloud.name || flavor == AccountType.plus.name;

class PrivateDnsCheck with Actor, Logging {
  late final _api = Core.get<Api>();

  void onRegister() {
    Core.register<PrivateDnsCheck>(this);
  }

  bool isCorrect(Marker m, String line, DeviceTag tag, String alias) {
    if (line.contains("%")) {
      line = line.urlDecode;
    }

    log(m).pair("current dns", line);

    var expected = getIosPrivateDnsStringV6(m, tag, alias);

    if (Core.act.isAndroid && Core.act.flavor == Flavor.family) {
      expected = getAndroidPrivateDnsStringFamily(m, tag);
    } else if (Core.act.isAndroid) {
      expected = getAndroidPrivateDnsString(m, tag, alias);
    } else if (Core.act.flavor == Flavor.family) {
      expected = _getIosPrivateDnsStringFamily(m, tag, alias);
    }

    log(m).pair("expects dns", expected);

    return line == expected;
  }

  /// Returns the Blokada flavor (`AccountType` name, e.g. `cloud`/`plus`/`family`)
  /// that currently owns this device's DNS, or null when DNS is not routed
  /// through Blokada. No device tag is sent: Family only needs to know whether
  /// DNS is already owned, and by which flavor, so it can defer to Blokada 6
  /// instead of running its own onboarding. This reflects the *live* routing —
  /// it catches cases a local check can't (v6 installed but not protecting, DNS
  /// turned off in Settings, a plan cancelled outside the app, a web-installed
  /// profile). Throws on network/parse failure so callers keep their previous
  /// decision rather than assuming "none" on a transient blip.
  // FamilyActor and PermActor both probe ownership on the same foreground /
  // cold-start burst. Share one in-flight request and briefly memoize the
  // result so they get a single identical answer instead of two competing
  // network calls that could disagree; foregrounds past the TTL re-probe fresh.
  static const _ownerCacheTtl = Duration(seconds: 5);
  String? _ownerFlavor;
  DateTime? _ownerFlavorAt;
  Future<String?>? _ownerFlavorInflight;

  Future<String?> getDnsOwnerFlavor(Marker m) {
    final at = _ownerFlavorAt;
    if (at != null && DateTime.now().difference(at) < _ownerCacheTtl) {
      return Future.value(_ownerFlavor);
    }
    return _ownerFlavorInflight ??=
        _probeDnsOwnerFlavor(m).whenComplete(() => _ownerFlavorInflight = null);
  }

  Future<String?> _probeDnsOwnerFlavor(Marker m) async {
    // Single attempt: this sits on the Family cold-start / foreground path, so
    // avoid the default 3x retry + retry-sleep stalls on a flaky connection. A
    // failure is non-fatal — callers fall back to their previous decision, and
    // it is not memoized so the next call retries.
    final response = await _api.request(
      ApiEndpoint.getStatusTestNoTag,
      m,
      skipResolvingParams: true,
      attempts: 1,
    );
    final json = jsonDecode(response);
    // Defensive: don't let an unexpected non-string flavor throw a CastError
    // here — that would be swallowed by callers and silently drop the v6
    // ownership signal. A non-string flavor maps to "not a known owner".
    final rawFlavor = json['flavor'];
    final flavor =
        json['blokada_dns'] == true && rawFlavor is String ? rawFlavor : null;
    _ownerFlavor = flavor;
    _ownerFlavorAt = DateTime.now();
    return flavor;
  }

  Future<bool> checkPrivateDnsEnabledWithApi(Marker m, DeviceTag deviceTag) async {
    try {
      final params = {
        ApiParam.deviceTag: deviceTag,
      };

      final response = await _api.get(
        ApiEndpoint.getStatusTest,
        m,
        params: params,
      );

      final json = jsonDecode(response);
      return json['blokada_dns'] == true;
    } catch (e) {
      log(m).e(msg: "checkPrivateDnsEnabledWithApi", err: e);
      return false;
    }
  }

  String getIosPrivateDnsStringV6(Marker m, DeviceTag tag, String alias) {
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
      return "https://cloud.blokada.org/$tag";
    } catch (e) {
      log(m).e(msg: "getIosPrivatDnsStringFamily", err: e);
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

  String getAndroidPrivateDnsStringFamily(Marker m, DeviceTag tag) {
    try {
      return "$tag.cloud.blokada.org";
    } catch (e) {
      log(m).e(msg: "getAndroidPrivateDnsStringFamily", err: e);
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
