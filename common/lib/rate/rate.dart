import 'dart:convert';

import 'package:common/logger/logger.dart';
import 'package:dartx/dartx.dart';
import 'package:mobx/mobx.dart';

import '../app/app.dart';
import '../common/model.dart';
import '../dragon/family/family.dart';
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

abstract class RateStoreBase with Store, Logging, Dependable, Startable {
  late final _ops = dep<RateOps>();
  late final _persistence = dep<PersistenceService>();
  late final _stage = dep<StageStore>();
  late final _app = dep<AppStore>();
  late final _stats = dep<StatsStore>();
  late final _family = dep<FamilyStore>();
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

  @override
  @action
  Future<void> start(Marker m) async {
    return await log(m).trace("start", (m) async {
      await load(m);
    });
  }

  @action
  onAppStatusChanged(Marker m) async {
    return await log(m).trace("onAppStatusChanged", (m) async {
      // Let the things settle a bit
      _timer.set(_keyTimer, DateTime.now().add(const Duration(seconds: 3)));
    });
  }

  @action
  Future<void> onTimerFired(Marker m) async {
    return await log(m).trace("onTimerFired", (m) async {
      if (!_app.status.isActive()) return; // When app got active ...
      final meta = rateMetadata;
      if (meta == null) return; // .. but not on first ever app start
      if (meta.lastSeen != null) return; // ... and not if shown previously
      if (!_stage.route.isMainRoute()) return; // Skip if already showing stuff

      if (!act.isFamily()) {
        if (_stats.stats.totalBlocked < 100) return; // Skip if not warmed up
      } else {
        // Skip if no devices
        if (_family.phase != FamilyPhase.parentHasDevices) return;
        // Skip if not warmed up
        if (_stats.deviceStats.none((k, v) => v.totalBlocked >= 100)) return;
      }

      await show(m);
    });
  }

  @action
  load(Marker m) async {
    return await log(m).trace("load", (m) async {
      final json = await _persistence.load(_key, m);
      if (json != null) {
        rateMetadata = JsonRate.fromJson(jsonDecode(json));
      } else {
        // Save the default metadata for the next app start
        await _persistence.save(_key, JsonRate().toJson(), m);
      }
    });
  }

  @action
  show(Marker m) async {
    return await log(m).trace("show", (m) async {
      final lastSeen = DateTime.now();
      JsonRate? meta = rateMetadata;
      if (meta == null) {
        meta = JsonRate(lastSeen: lastSeen);
      } else {
        meta = JsonRate(lastSeen: lastSeen, lastRate: meta.lastRate);
      }
      await _persistence.save(_key, meta.toJson(), m);
      await _stage.showModal(StageModal.rate, m);
    });
  }

  @action
  rate(int rate, bool showPlatformDialog, Marker m) async {
    return await log(m).trace("rate", (m) async {
      JsonRate? meta = rateMetadata;
      meta =
          JsonRate(lastSeen: meta?.lastSeen ?? DateTime.now(), lastRate: rate);
      await _persistence.save(_key, meta.toJson(), m);
      rateMetadata = meta;

      if (rate >= 4 && showPlatformDialog) {
        await _ops.doShowRateDialog();
      }
    });
  }
}
