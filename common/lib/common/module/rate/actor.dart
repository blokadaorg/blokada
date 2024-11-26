part of 'rate.dart';

mixin RateChannel {
  Future<void> doShowRateDialog();
}

class RateActor with Logging, Actor {
  late final _channel = DI.get<RateChannel>();
  late final _stage = DI.get<StageStore>();
  late final _app = DI.get<AppStore>();
  late final _stats = DI.get<StatsStore>();
  late final _familyPhase = DI.get<FamilyPhaseValue>();
  late final _scheduler = DI.get<Scheduler>();

  late final _rateMetadata = RateMetadataValue();

  @override
  onStart(Marker m) async {
    return await log(m).trace("start", (m) async {
      _app.addOn(appStatusChanged, _scheduleAfterAppStatus);
      await _load(m);
    });
  }

  _scheduleAfterAppStatus(Marker m) async {
    return await log(m).trace("scheduleAfterAppStatus", (m) async {
      // Let the things settle a bit
      await _scheduler.addOrUpdate(Job(
        "rate:checkConditions",
        m,
        before: DateTime.now().add(const Duration(seconds: 3)),
        when: [Conditions.foreground],
        callback: checkRateConditions,
      ));
    });
  }

  Future<bool> checkRateConditions(Marker m) async {
    // When app got active ...
    if (!_app.status.isActive()) return false;

    final meta = await _rateMetadata.now();

    // .. but not on first ever app start
    if (meta == null) return false;

    // ... and not if shown previously
    if (meta.lastSeen != null) return false;

    // Skip if already showing stuff
    if (!_stage.route.isMainRoute()) return false;

    if (!act.isFamily) {
      // Skip if not warmed up
      if (_stats.stats.totalBlocked < 100) return false;
    } else {
      // Skip if no devices
      if (_familyPhase.now != FamilyPhase.parentHasDevices) return false;

      // Skip if not warmed up
      if (_stats.deviceStats.none((k, v) => v.totalBlocked >= 100)) {
        return false;
      }
    }

    await _show(m);
    return true;
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

  _show(Marker m) async {
    return await log(m).trace("show", (m) async {
      final lastSeen = DateTime.now();
      JsonRate? meta = await _rateMetadata.now();
      if (meta == null) {
        meta = JsonRate(lastSeen: lastSeen);
      } else {
        meta = JsonRate(lastSeen: lastSeen, lastRate: meta.lastRate);
      }
      _rateMetadata.change(m, meta);
      await _stage.showModal(StageModal.rate, m);
    });
  }

  _rate(int rate, bool showPlatformDialog, Marker m) async {
    return await log(m).trace("rate", (m) async {
      JsonRate? meta = await _rateMetadata.now();
      meta =
          JsonRate(lastSeen: meta?.lastSeen ?? DateTime.now(), lastRate: rate);
      _rateMetadata.change(m, meta);

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
