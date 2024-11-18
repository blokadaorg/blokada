import 'dart:convert';

import 'package:common/core/core.dart';
import 'package:dartx/dartx.dart';
import 'package:mobx/mobx.dart';

import '../../common/model/model.dart';
import '../../dragon/family/family.dart';
import '../../timer/timer.dart';
import '../app/app.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../stats/stats.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'rate.g.dart';

const String _key = "rate:metadata";
const String _keyTimer = "rate:checkConditions";

class RateStore = RateStoreBase with _$RateStore;

abstract class RateStoreBase with Store, Logging, Actor {
  late final _ops = DI.get<RateOps>();
  late final _persistence = DI.get<Persistence>();
  late final _stage = DI.get<StageStore>();
  late final _app = DI.get<AppStore>();
  late final _stats = DI.get<StatsStore>();
  late final _family = DI.get<FamilyStore>();
  late final _timer = DI.get<TimerService>();

  RateStoreBase() {
    _timer.addHandler(_keyTimer, onTimerFired);
    _app.addOn(appStatusChanged, onAppStatusChanged);
  }

  @override
  onRegister(Act act) {
    DI.register<RateOps>(getOps(act));
    DI.register<RateStore>(this as RateStore);
  }

  @observable
  JsonRate? rateMetadata;

  @override
  Future<void> onStart(Marker m) async {
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

      if (!act.isFamily) {
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
      final json = await _persistence.load(_key);
      if (json != null) {
        rateMetadata = JsonRate.fromJson(jsonDecode(json));
      } else {
        // Save the default metadata for the next app start
        await _persistence.saveJson(_key, JsonRate().toJson());
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
      await _persistence.saveJson(_key, meta.toJson());
      await _stage.showModal(StageModal.rate, m);
    });
  }

  @action
  rate(int rate, bool showPlatformDialog, Marker m) async {
    return await log(m).trace("rate", (m) async {
      JsonRate? meta = rateMetadata;
      meta =
          JsonRate(lastSeen: meta?.lastSeen ?? DateTime.now(), lastRate: rate);
      await _persistence.saveJson(_key, meta.toJson());
      rateMetadata = meta;

      if (rate >= 4 && showPlatformDialog) {
        await _ops.doShowRateDialog();
      }
    });
  }
}
