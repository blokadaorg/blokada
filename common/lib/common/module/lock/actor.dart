part of 'lock.dart';

class LockActor with Logging, Actor {
  late final _stage = DI.get<StageStore>();

  late final isLocked = DI.get<IsLocked>();
  late final _hasPin = DI.get<HasPin>();
  late final _existingPin = DI.get<ExistingPin>();

  @override
  onStart(Marker m) async {
    return await log(m).trace("onStart", (m) async {
      _stage.addOn(willEnterBackground, _autoLockOnBackground);
      if (!act.isFamily) await _stage.setShowNavbar(false, m);
      await _load(m);
    });
  }

  _load(Marker m) async {
    return await log(m).trace("load", (m) async {
      await _existingPin.fetch(m);
      _hasPin.now = _existingPin.present != null;
      isLocked.now = _hasPin.now;
      if (isLocked.now) {
        await _stage.showModal(StageModal.lock, m);
      } else {
        if (!act.isFamily) await _stage.setShowNavbar(true, m);
      }
    });
  }

  lock(Marker m, String pin) async {
    return await log(m).trace("lock", (m) async {
      if (isLocked.now) {
        return;
      }

      if (pin.length != 4 || !isNumeric(pin)) {
        await _stage.showModal(StageModal.faultLockInvalid, m);
        throw Exception("Invalid pin format: $pin");
      }

      _existingPin.change(m, pin);
      isLocked.now = true;
      _hasPin.now = true;
      if (!act.isFamily) await _stage.setShowNavbar(false, m);
    });
  }

  canUnlock(Marker m, String pin) async {
    return await log(m).trace("canUnlock", (m) async {
      if (_existingPin.present == null) {
        throw Exception("Pin not set");
      }

      if (_existingPin.present != pin) {
        throw Exception("Invalid pin");
      }

      // No crash means the pin is correct
    });
  }

  unlock(Marker m, String pin) async {
    return await log(m).trace("unlock", (m) async {
      await canUnlock(m, pin);

      isLocked.now = false;
      if (!act.isFamily) await _stage.setShowNavbar(true, m);
    });
  }

  // Sets lock, but does not lock immediately
  setLock(Marker m, String pin) async {
    return await log(m).trace("setLock", (m) async {
      if (isLocked.now) {
        return;
      }

      if (pin.length != 4 || !isNumeric(pin)) {
        await _stage.showModal(StageModal.faultLockInvalid, m);
        throw Exception("Invalid pin format: $pin");
      }

      _existingPin.change(m, pin);
      _hasPin.now = true;
    });
  }

  removeLock(Marker m) async {
    return await log(m).trace("removeLock", (m) async {
      if (_existingPin.present == null) return;
      final pin = _existingPin.present!;
      await unlock(m, pin);
      _existingPin.change(m, null);
      _hasPin.now = false;
    });
  }

  autoLock(Marker m) async {
    return await log(m).trace("autoLock", (m) async {
      if (_hasPin.now) {
        await lock(m, _existingPin.present!);
      }
      await _stage.showModal(StageModal.lock, m);
    });
  }

  _autoLockOnBackground(Marker m) async {
    if (_hasPin.now) {
      return await log(m).trace("autoLockOnBackground", (m) async {
        await _stage.setRoute("home", m);
        await _stage.showModal(StageModal.lock, m);
        await lock(m, _existingPin.present!);
      });
    }
  }
}
