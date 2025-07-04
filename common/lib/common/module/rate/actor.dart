part of 'rate.dart';

class RateMetadataValue extends JsonPersistedValue<JsonRate> {
  RateMetadataValue() : super("rate:metadata:2025");

  @override
  JsonRate fromJson(Map<String, dynamic> json) => JsonRate.fromJson(json);

  @override
  Map<String, dynamic> toJson(JsonRate value) => value.toJson();
}

class RateActor with Logging, Actor {
  late final _channel = Core.get<RateChannel>();
  late final _stage = Core.get<StageStore>();
  late final _app = Core.get<AppStore>();
  late final _stats = Core.get<StatsStore>();
  late final _familyStats = Core.get<StatsActor>();
  late final _familyPhase = Core.get<FamilyPhaseValue>();
  late final _scheduler = Core.get<Scheduler>();
  late final _account = Core.get<AccountStore>();

  late final _rateMetadata = RateMetadataValue();

  @override
  onStart(Marker m) async {
    return await log(m).trace("start", (m) async {
      _app.addOn(appStatusChanged, _scheduleAfterAppStatus);
      _account.addOn(accountChanged, _trackFreemiumYoutubeActivation);
      await _load(m);
    });
  }

  _scheduleAfterAppStatus(Marker m) async {
    return await log(m).trace("scheduleAfterAppStatus", (m) async {
      // Let the things settle a bit
      await _scheduler.addOrUpdate(Job(
        "rate:checkConditions",
        m,
        before: DateTime.now().add(const Duration(seconds: 5)),
        when: [Conditions.foreground],
        callback: checkRateConditions,
      ));
    });
  }

  _trackFreemiumYoutubeActivation(Marker m) async {
    return await log(m).trace("trackFreemiumYoutubeActivation", (m) async {
      final account = _account.account;
      if (account == null) return;
      
      final attributes = account.jsonAccount.attributes ?? {};
      final freemiumYoutubeUntil = attributes['freemium_youtube_until'] as String?;
      
      if (freemiumYoutubeUntil != null) {
        final meta = await _rateMetadata.now();
        if (meta != null && meta.freemiumYoutubeActivatedTime == null) {
          // First time YouTube freemium is activated, store the timestamp
          final updatedMeta = JsonRate(
            lastSeen: meta.lastSeen,
            lastRate: meta.lastRate,
            freemiumYoutubeActivatedTime: DateTime.now(),
          );
          await _rateMetadata.change(m, updatedMeta);
        }
      }
    });
  }

  bool _shouldShowForFreemiumYoutube(JsonRate meta) {
    // Must have freemium YouTube activated timestamp
    if (meta.freemiumYoutubeActivatedTime == null) return false;
    
    // Must be at least 2 days since freemium YouTube was activated
    final now = DateTime.now();
    final daysSinceActivation = now.difference(meta.freemiumYoutubeActivatedTime!).inDays;
    return daysSinceActivation >= 2;
  }

  Future<bool> checkRateConditions(Marker m) async {
    final meta = await _rateMetadata.now();

    // Not on first ever app start
    if (meta == null) return false;

    // ... and not if shown previously
    if (meta.lastSeen != null) return false;

    // Skip if already showing stuff
    if (!_stage.route.isMainRoute()) return false;

    // Check for freemium YouTube condition (for non-family apps)
    if (!Core.act.isFamily && _account.isFreemium && _shouldShowForFreemiumYoutube(meta)) {
      await show(m);
      return false;
    }

    if (!Core.act.isFamily) {
      // Only when app got active ...
      if (!_app.status.isActive()) return false;

      // Skip if not warmed up
      if (_stats.stats.totalBlocked < 100) return false;
    } else {
      // Skip if no devices
      if (_familyPhase.now != FamilyPhase.parentHasDevices) {
        log(m).t("Skipped because no devices");
        return false;
      }

      // Skip if not warmed up
      if (_familyStats.stats.values.none((it) => it.totalBlocked >= 100)) {
        log(m).t("Skipped because no device has 100+ blocked");
        return false;
      }
    }

    await show(m);
    return false;
  }

  _load(Marker m) async {
    return await log(m).trace("load", (m) async {
      await _rateMetadata.fetch(m);
      if (_rateMetadata.present == null) {
        // Save the default metadata for the next app start
        await _rateMetadata.change(m, JsonRate());
      }
    });
  }

  show(Marker m) async {
    return await log(m).trace("show", (m) async {
      final lastSeen = DateTime.now();
      JsonRate? meta = await _rateMetadata.now();
      if (meta == null) {
        meta = JsonRate(lastSeen: lastSeen);
      } else {
        meta = JsonRate(
          lastSeen: lastSeen, 
          lastRate: meta.lastRate,
          freemiumYoutubeActivatedTime: meta.freemiumYoutubeActivatedTime,
        );
      }
      await _rateMetadata.change(m, meta);
      await _stage.showModal(StageModal.rate, m);
    });
  }

  _rate(int rate, bool showPlatformDialog, Marker m) async {
    return await log(m).trace("rate", (m) async {
      JsonRate? meta = await _rateMetadata.now();
      meta = JsonRate(
        lastSeen: meta?.lastSeen ?? DateTime.now(), 
        lastRate: rate,
        freemiumYoutubeActivatedTime: meta?.freemiumYoutubeActivatedTime,
      );
      await _rateMetadata.change(m, meta);

      if (rate >= 4 && showPlatformDialog) {
        await _channel.doShowRateDialog();
      }
    });
  }

  onUserTapRate(int rating, bool showPlatformDialog) async {
    await log(Markers.userTap).trace("tappedCloseRateScreen", (m) async {
      await _stage.dismissModal(m);
      await _rate(rating, showPlatformDialog, m);
    });
  }
}
