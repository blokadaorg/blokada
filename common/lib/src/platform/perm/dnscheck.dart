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

    if (Core.act.isAndroid) {
      final correct = isAndroidHostnameForTag(line, tag);
      log(m).pair("expects dns", "any hostname for this tag");
      return correct;
    }

    var expected = getIosPrivateDnsStringV6(m, tag, alias);
    if (Core.act.flavor == Flavor.family) {
      expected = _getIosPrivateDnsStringFamily(m, tag, alias);
    }

    log(m).pair("expects dns", expected);

    return line == expected;
  }

  /// Whether an Android Private DNS hostname belongs to this device tag.
  /// People type the hostname by hand, so any form we hand out for the tag is
  /// accepted: `<tag>.cloud.blokada.org` (Family) and
  /// `<alias>-<tag>.cloud.blokada.org` (Blokada 6), whatever the alias.
  /// Case, surrounding spaces and a trailing dot are ignored.
  static bool isAndroidHostnameForTag(String hostname, DeviceTag tag) {
    var host = hostname.trim().toLowerCase();
    if (host.endsWith(".")) host = host.substring(0, host.length - 1);
    final t = tag.trim().toLowerCase();
    if (t.isEmpty) return false;

    const domain = ".cloud.blokada.org";
    if (!host.endsWith(domain)) return false;
    final label = host.substring(0, host.length - domain.length);
    if (label == t) return true;
    return label.length > t.length + 1 && label.endsWith("-$t");
  }

  /// Whether a hostname points at Blokada at all, used to tell a typo in our
  /// hostname apart from some other DNS provider.
  static bool isBlokadaHostname(String hostname) {
    var host = hostname.trim().toLowerCase();
    if (host.endsWith(".")) host = host.substring(0, host.length - 1);
    return host == "cloud.blokada.org" || host.endsWith(".cloud.blokada.org");
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

  /// [fresh] skips the memoized answer, for callers that retry right after a
  /// DNS change (the Android setup sheet), where a cached "none" is stale.
  Future<String?> getDnsOwnerFlavor(Marker m, {bool fresh = false}) {
    final at = _ownerFlavorAt;
    if (!fresh && at != null && DateTime.now().difference(at) < _ownerCacheTtl) {
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
