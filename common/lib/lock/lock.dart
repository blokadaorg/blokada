import 'package:common/stage/channel.pg.dart';
import 'package:mobx/mobx.dart';

import '../persistence/persistence.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';

part 'lock.g.dart';

const _keyLock = "lock:pin";

class LockStore = LockStoreBase with _$LockStore;

abstract class LockStoreBase with Store, Traceable, Dependable {
  late final _persistence = dep<PersistenceService>();
  late final _stage = dep<StageStore>();

  LockStoreBase() {
    _stage.addOnValue(routeChanged, onRouteChanged);
  }

  @override
  attach(Act act) {
    depend<LockStore>(this as LockStore);
  }

  @observable
  bool isLocked = false;

  @observable
  bool hasPin = false;

  String? _existingPin;

  @action
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (route.isBecameForeground()) {
      return await traceWith(parentTrace, "checkLock", (trace) async {
        await load(trace);
      });
    } else if (!route.isForeground()) {
      // return await traceWith(parentTrace, "lockForBg", (trace) async {
      //   await _stage.setLocked(trace, true);
      // });
    }
  }

  @action
  Future<void> load(Trace parentTrace) async {
    return await traceWith(parentTrace, "load", (trace) async {
      _existingPin = await _persistence.load(trace, _keyLock);
      hasPin = _existingPin != null;
      isLocked = hasPin;
      if (hasPin) {
        await _stage.setRoute(trace, StageKnownRoute.homeOverlayLock.path);
      }

      //await _stage.setLocked(trace, hasPin);
    });
  }

  @action
  Future<void> lock(Trace parentTrace, String pin) async {
    return await traceWith(parentTrace, "lock", (trace) async {
      if (isLocked) {
        throw Exception("Cannot lock when already locked");
      }

      await _persistence.saveString(trace, _keyLock, pin);
      _existingPin = pin;
      isLocked = true;
      hasPin = true;
      //await _stage.setLocked(trace, true);
      await _stage.setRoute(trace, StageKnownRoute.homeOverlayLock.path);
    });
  }

  @action
  Future<void> unlock(Trace parentTrace, String pin) async {
    return await traceWith(parentTrace, "unlock", (trace) async {
      if (_existingPin == null) {
        throw Exception("Pin not set");
      }

      if (_existingPin != pin) {
        throw Exception("Invalid pin");
      }

      isLocked = false;
      //await _stage.setLocked(trace, false);
    });
  }

  @action
  Future<void> removeLock(Trace parentTrace) async {
    return await traceWith(parentTrace, "removeLock", (trace) async {
      final pin = _existingPin!;
      await unlock(trace, pin);
      _existingPin = null;
      hasPin = false;
      await _persistence.delete(trace, _keyLock);
    });
  }
}
