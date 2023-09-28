import 'dart:convert';

import 'package:mobx/mobx.dart';

import '../app/app.dart';
import '../onboard/onboard.dart';
import '../persistence/persistence.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../stats/stats.dart';
import '../timer/timer.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'rate.g.dart';

const String _key = "rate:metadata";
const String _keyTimer = "rate:checkConditions";

class RateStore = RateStoreBase with _$RateStore;

abstract class RateStoreBase with Store, Traceable, Dependable {
  late final _ops = dep<RateOps>();
  late final _persistence = dep<PersistenceService>();
  late final _stage = dep<StageStore>();
  late final _app = dep<AppStore>();
<<<<<<< HEAD
  late final _stats = dep<StatsStore>();
=======
  late final _onboard = dep<OnboardStore>();
>>>>>>> 399c4e3 (reorganize onboard for both flavors)
  late final _timer = dep<TimerService>();

  RateStoreBase() {
    _timer.addHandler(_keyTimer, onTimerFired);
    _app.addOn(appStatusChanged, onAppStatusChanged);
  }

  @override
  attach(Act act) {
    depend<RateOps>(getOps(act));
    depend<RateStore>(this as RateStore);
  }

  @observable
  JsonRate? rateMetadata;

  @action
  onAppStatusChanged(Trace parentTrace) async {
    return await traceWith(parentTrace, "onAppStatusChanged", (trace) async {
      // Let the things settle a bit
      _timer.set(_keyTimer, DateTime.now().add(const Duration(seconds: 3)));
    });
  }

  @action
  Future<void> onTimerFired(Trace parentTrace) async {
    return await traceWith(parentTrace, "onTimerFired", (trace) async {
      if (!_app.status.isActive()) return; // When app got active ...
      final meta = rateMetadata;
      if (meta == null) return; // .. but not on first ever app start
      if (meta.lastSeen != null) return; // ... and not if shown previously
      if (!_stage.route.isMainRoute()) return; // Skip if already showing stuff
<<<<<<< HEAD
      if (_stats.stats.totalBlocked < 100) return; // Skip if not warmed up
=======
      if (!_onboard.isOnboarded) return; // Skip if not onboarded yet
>>>>>>> 399c4e3 (reorganize onboard for both flavors)

      await show(trace);
    });
  }

  @action
  load(Trace parentTrace) async {
    return await traceWith(parentTrace, "load", (trace) async {
      final json = await _persistence.load(trace, _key);
      if (json != null) {
        rateMetadata = JsonRate.fromJson(jsonDecode(json));
      } else {
        // Save the default metadata for the next app start
        await _persistence.save(trace, _key, JsonRate().toJson());
      }
    });
  }

  @action
  show(Trace parentTrace) async {
    return await traceWith(parentTrace, "show", (trace) async {
      final lastSeen = DateTime.now();
      JsonRate? meta = rateMetadata;
      if (meta == null) {
        meta = JsonRate(lastSeen: lastSeen);
      } else {
        meta = JsonRate(lastSeen: lastSeen, lastRate: meta.lastRate);
      }
      await _persistence.save(trace, _key, meta.toJson());
      await _stage.setRoute(trace, StageKnownRoute.homeOverlayRate.path);
    });
  }

  @action
  rate(Trace parentTrace, int rate, bool showPlatformDialog) async {
    return await traceWith(parentTrace, "rate", (trace) async {
      JsonRate? meta = rateMetadata;
      meta =
          JsonRate(lastSeen: meta?.lastSeen ?? DateTime.now(), lastRate: rate);
      await _persistence.save(trace, _key, meta.toJson());
      rateMetadata = meta;

      if (rate >= 4 && showPlatformDialog) {
        await _ops.doShowRateDialog();
      }
    });
  }
}
