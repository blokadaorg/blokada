import 'dart:convert';

import 'package:common/util/async.dart';
import 'package:mobx/mobx.dart';

import '../app/app.dart';
import '../persistence/persistence.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'rate.g.dart';

const String _key = "rate:metadata";

class RateStore = RateStoreBase with _$RateStore;

abstract class RateStoreBase with Store, Traceable, Dependable {
  late final _ops = dep<RateOps>();
  late final _persistence = dep<PersistenceService>();
  late final _stage = dep<StageStore>();
  late final _app = dep<AppStore>();

  RateStoreBase() {
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
      if (!_app.status.isActive()) return; // When app got active ...
      final meta = rateMetadata;
      if (meta == null) return; // .. but not on first ever app start
      if (meta.lastSeen != null) return; // ... and not if shown previously

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
      await sleepAsync(const Duration(seconds: 3));
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
