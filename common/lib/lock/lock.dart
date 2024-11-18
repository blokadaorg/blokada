import 'package:common/core/core.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:mobx/mobx.dart';
import 'package:string_validator/string_validator.dart';

import '../platform/persistence/persistence.dart';
import '../platform/stage/stage.dart';

part 'lock.g.dart';

final lockChanged = EmitterEvent<bool>("lockChanged");

const _keyLock = "lock:pin";

class LockStore = LockStoreBase with _$LockStore;

abstract class LockStoreBase with Store, Logging, Actor, ValueEmitter<bool> {
  late final _persistence = dep<PersistenceService>();
  late final _stage = dep<StageStore>();

  LockStoreBase() {
    willAcceptOnValue(lockChanged);
    _stage.addOn(willEnterBackground, _autoLockOnBackground);
  }

  @override
  onRegister(Act act) {
    depend<LockStore>(this as LockStore);
  }

  @observable
  bool isLocked = true;

  @observable
  bool hasPin = false;

  String? _existingPin;

  @override
  Future<void> onStart(Marker m) async {
    return await log(m).trace("start", (m) async {
      if (!act.isFamily) await _stage.setShowNavbar(false, m);
      await load(m);
    });
  }

  @action
  Future<void> load(Marker m) async {
    return await log(m).trace("load", (m) async {
      _existingPin = await _persistence.load(_keyLock, m);
      hasPin = _existingPin != null;
      isLocked = hasPin;
      await emitValue(lockChanged, isLocked, m);
      if (isLocked) {
        await _stage.showModal(StageModal.lock, m);
      } else {
        if (!act.isFamily) await _stage.setShowNavbar(true, m);
      }
    });
  }

  @action
  Future<void> lock(String pin, Marker m) async {
    return await log(m).trace("lock", (m) async {
      if (isLocked) {
        return;
      }

      if (pin.length != 4 || !isNumeric(pin)) {
        await _stage.showModal(StageModal.faultLockInvalid, m);
        throw Exception("Invalid pin format: $pin");
      }

      await _persistence.saveString(_keyLock, pin, m);
      _existingPin = pin;
      isLocked = true;
      hasPin = true;
      await emitValue(lockChanged, true, m);
      if (!act.isFamily) await _stage.setShowNavbar(false, m);
    });
  }

  @action
  Future<void> canUnlock(String pin, Marker m) async {
    return await log(m).trace("canUnlock", (m) async {
      if (_existingPin == null) {
        throw Exception("Pin not set");
      }

      if (_existingPin != pin) {
        throw Exception("Invalid pin");
      }

      // No crash means the pin is correct
    });
  }

  @action
  Future<void> unlock(String pin, Marker m) async {
    return await log(m).trace("unlock", (m) async {
      await canUnlock(pin, m);

      isLocked = false;
      await emitValue(lockChanged, false, m);
      if (!act.isFamily) await _stage.setShowNavbar(true, m);
    });
  }

  // Sets lock, but does not lock immediately
  @action
  Future<void> setLock(String pin, Marker m) async {
    return await log(m).trace("setLock", (m) async {
      if (isLocked) {
        return;
      }

      if (pin.length != 4 || !isNumeric(pin)) {
        await _stage.showModal(StageModal.faultLockInvalid, m);
        throw Exception("Invalid pin format: $pin");
      }

      await _persistence.saveString(_keyLock, pin, m);
      _existingPin = pin;
      hasPin = true;
    });
  }

  @action
  Future<void> removeLock(Marker m) async {
    return await log(m).trace("removeLock", (m) async {
      if (_existingPin == null) return;
      final pin = _existingPin!;
      await unlock(pin, m);
      _existingPin = null;
      hasPin = false;
      await _persistence.delete(_keyLock, m);
    });
  }

  @action
  Future<void> autoLock(Marker m) async {
    return await log(m).trace("autoLock", (m) async {
      if (hasPin) {
        await lock(_existingPin!, m);
      }
      await _stage.showModal(StageModal.lock, m);
    });
  }

  _autoLockOnBackground(Marker m) async {
    if (hasPin) {
      return await log(m).trace("autoLockOnBackground", (m) async {
        await _stage.setRoute("home", m);
        await _stage.showModal(StageModal.lock, m);
        await lock(_existingPin!, m);
      });
    }
  }
}
