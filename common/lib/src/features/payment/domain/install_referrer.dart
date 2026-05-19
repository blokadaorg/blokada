part of 'payment.dart';

/// Parsed Google Play Install Referrer.
///
/// The referrer is a URL-encoded query fragment, e.g. for organic Play installs
/// `utm_source=google-play&utm_medium=organic`, and for Google Ads
/// `gclid=...&utm_source=google&utm_medium=cpc&utm_campaign=...`.
class InstallReferrerData {
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmContent;
  final String? utmTerm;
  final String? gclid;
  final String? rawReferrer;
  final bool isOrganic;

  InstallReferrerData({
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmContent,
    this.utmTerm,
    this.gclid,
    this.rawReferrer,
    required this.isOrganic,
  });

  factory InstallReferrerData.organic() =>
      InstallReferrerData(isOrganic: true);

  /// Never throws. A null/empty referrer (sideload, debug, non-Play) yields
  /// an organic record. A malformed referrer keeps [rawReferrer] but parses
  /// best-effort.
  static InstallReferrerData parse(String? referrerUrl) {
    if (referrerUrl == null || referrerUrl.trim().isEmpty) {
      return InstallReferrerData.organic();
    }

    Map<String, String> q = {};
    try {
      q = Uri.splitQueryString(referrerUrl);
    } catch (_) {
      q = {};
    }

    String? g(String k) {
      final v = q[k];
      return (v == null || v.isEmpty) ? null : v;
    }

    final source = g('utm_source');
    final medium = g('utm_medium');
    final gclid = g('gclid');

    // Google Ads installs carry a gclid (and usually utm_medium=cpc). Play
    // organic installs report utm_source=google-play&utm_medium=organic.
    final mediumLc = medium?.toLowerCase();
    final isOrganic = gclid == null &&
        (source == null || source == 'google-play' || source == '(not set)') &&
        mediumLc != 'cpc' &&
        mediumLc != 'paid';

    return InstallReferrerData(
      utmSource: source,
      utmMedium: medium,
      utmCampaign: g('utm_campaign'),
      utmContent: g('utm_content'),
      utmTerm: g('utm_term'),
      gclid: gclid,
      rawReferrer: referrerUrl,
      isOrganic: isOrganic,
    );
  }

  static String _truncate(String v, int max) =>
      v.length > max ? v.substring(0, max) : v;

  /// Adapty `updateAttribution` payload (recommended keys, each <=50 chars).
  /// `status` is always present; other keys are omitted when empty.
  Map<String, dynamic> toAttributionMap() {
    final map = <String, dynamic>{};
    map['status'] = isOrganic ? 'organic' : 'non_organic';

    final channel = utmSource ?? (isOrganic ? 'google-play' : null);
    if (channel != null && channel.isNotEmpty) {
      map['channel'] = _truncate(channel, 50);
    }
    if (utmCampaign != null && utmCampaign!.isNotEmpty) {
      map['campaign'] = _truncate(utmCampaign!, 50);
    }
    if (utmTerm != null && utmTerm!.isNotEmpty) {
      map['ad_group'] = _truncate(utmTerm!, 50);
    }
    final adSet = utmMedium ?? (isOrganic ? 'organic' : null);
    if (adSet != null && adSet.isNotEmpty) {
      map['ad_set'] = _truncate(adSet, 50);
    }
    if (utmContent != null && utmContent!.isNotEmpty) {
      map['creative'] = _truncate(utmContent!, 50);
    }
    return map;
  }

  static List<String> _chunk(String s, int size, int maxChunks) {
    final out = <String>[];
    for (var i = 0; i < s.length && out.length < maxChunks; i += size) {
      out.add(s.substring(i, i + size > s.length ? s.length : i + size));
    }
    return out;
  }

  /// gclid stashed as Adapty custom attributes for downstream BI join.
  /// Bypasses [AdaptyAttributeConverter] (its 30-char value cap would destroy
  /// the gclid); chunked to Adapty's real ~50-char per-value limit. A gclid is
  /// typically <100 chars, so at most 2 chunks; capped at 4 defensively.
  List<Map<String, dynamic>> buildCustomAttributes() {
    final attrs = <Map<String, dynamic>>[];
    attrs.add({
      'key': 'acq_status',
      'value': isOrganic ? 'organic' : 'non_organic',
    });

    final gc = gclid;
    if (gc != null && gc.isNotEmpty) {
      final chunks = _chunk(gc, 50, 4);
      for (var i = 0; i < chunks.length; i++) {
        attrs.add({
          'key': i == 0 ? 'acq_gclid' : 'acq_gclid_$i',
          'value': chunks[i],
        });
      }
    }
    return attrs;
  }
}

/// Test seam over the Play Install Referrer system API.
mixin InstallReferrerChannel {
  Future<String?> fetchReferrerUrl();
}

class PlatformInstallReferrerChannel with Logging, InstallReferrerChannel {
  @override
  Future<String?> fetchReferrerUrl() async {
    // play_install_referrer throws on iOS / when Play Services are absent.
    if (!Core.act.isAndroid) return null;
    try {
      final details = await PlayInstallReferrer.installReferrer;
      return details.installReferrer;
    } catch (e) {
      // FEATURE_NOT_SUPPORTED / SERVICE_UNAVAILABLE / DEVELOPER_ERROR
      // (sideload, debug, non-Play install) -> treat as organic/unknown.
      log(Markers.root).i("Install referrer unavailable: $e");
      return null;
    }
  }
}

/// Once-per-install idempotency guard. Stored in non-secure `local`
/// SharedPreferences. Note: the app sets no allowBackup=false, so Android Auto
/// Backup may restore this on reinstall (no re-send) — acceptable, since
/// Adapty is one-source-per-profile and would reject a re-send anyway.
class InstallReferrerSentValue extends BoolPersistedValue {
  InstallReferrerSentValue() : super("payment:install_referrer_sent");
}

/// Captures the Google Play Install Referrer once and forwards it to Adapty
/// as acquisition-source attribution + gclid custom attributes. Routed via the
/// active [PaymentChannel] so v6 Android goes through the native Adapty SDK
/// (Pigeon) and family through the Adapty Flutter SDK.
class InstallReferrerService with Logging {
  late final _channel = Core.get<InstallReferrerChannel>();
  late final _payment = Core.get<PaymentChannel>();
  late final _sentGuard = Core.get<InstallReferrerSentValue>();

  Future<void> sendAttributionOnce(Marker m) async {
    // CRITICAL: iOS keeps automatic Apple Search Ads attribution. The trigger
    // in PaymentActor.onStart is cross-platform; on iOS PaymentChannel is the
    // Adapty Flutter SDK, and updateAttribution(source:"custom") there would
    // permanently clobber the ASA source (Adapty: one source per profile, no
    // override). Gate FIRST, before the guard and before any Adapty call.
    if (!Core.act.isAndroid) return;

    return await log(m).trace("installReferrerAttribution", (m) async {
      try {
        // fetch() (not now()) so the guard is loaded from persistence — it
        // must survive process restarts and is never resolved elsewhere.
        if (await _sentGuard.fetch(m)) {
          log(m).t("Install referrer attribution already sent, skip");
          return;
        }

        final url = await _channel.fetchReferrerUrl();
        final data = InstallReferrerData.parse(url);
        log(m).i("Install referrer: organic=${data.isOrganic}, "
            "hasGclid=${data.gclid != null}, available=${url != null}");

        await _payment.updateAttribution(m, data.toAttributionMap());

        final customAttrs = data.buildCustomAttributes();
        if (customAttrs.isNotEmpty) {
          await _payment
              .setCustomAttributes(m, {'custom_attributes': customAttrs});
        }

        // Reached only on success (incl. organic when referrer unavailable —
        // nothing better will ever arrive, so we never spin). On a transient
        // Adapty error we fall to catch and leave the guard unset to retry on
        // the next app start.
        await _sentGuard.change(m, true);
        log(m).i("Sent install referrer attribution to Adapty");
      } catch (e, s) {
        // Never rethrow: must not break the payment init/startup sequence.
        log(m).e(
            msg: "Failed sending install referrer attribution",
            err: e,
            stack: s);
      }
    });
  }
}
