import 'package:common/stage/channel.pg.dart';
import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../perm/perm.dart';
import '../persistence/persistence.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/emitter.dart';
import '../util/trace.dart';

part 'lock.g.dart';

final lockChanged = EmitterEvent<bool>();

const _keyLock = "lock:pin";

class LockStore = LockStoreBase with _$LockStore;

abstract class LockStoreBase
    with Store, Traceable, Dependable, Startable, ValueEmitter<bool> {
  late final _persistence = dep<PersistenceService>();
  late final _stage = dep<StageStore>();
  late final _perm = dep<PermStore>();
  late final _account = dep<AccountStore>();

  LockStoreBase() {
    willAcceptOnValue(lockChanged);
    _stage.addOn(willEnterBackground, _autoLockOnBackground);
  }

  @override
  attach(Act act) {
    depend<LockStore>(this as LockStore);
  }

  @observable
  bool isLocked = true;

  @observable
  bool hasPin = false;

  String? _existingPin;

  @override
  @action
  Future<void> start(Trace parentTrace) async {
    return await traceWith(parentTrace, "start", (trace) async {
      await _stage.setShowNavbar(trace, false);
      await load(trace);
    });
  }

  @action
  Future<void> load(Trace parentTrace) async {
    return await traceWith(parentTrace, "load", (trace) async {
      _existingPin = await _persistence.load(trace, _keyLock);
      hasPin = _existingPin != null;
      isLocked = hasPin;
      await emitValue(lockChanged, trace, hasPin);
      if (isLocked) {
        await _stage.showModal(trace, StageModal.lock);
      }
    });
  }

  @action
  Future<void> lock(Trace parentTrace, String pin) async {
    return await traceWith(parentTrace, "lock", (trace) async {
      if (isLocked) {
        return;
      }

      await _persistence.saveString(trace, _keyLock, pin);
      _existingPin = pin;
      isLocked = true;
      hasPin = true;
      await emitValue(lockChanged, trace, true);
    });
  }

  @action
  Future<void> canUnlock(Trace parentTrace, String pin) async {
    return await traceWith(parentTrace, "canUnlock", (trace) async {
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
  Future<void> unlock(Trace parentTrace, String pin) async {
    return await traceWith(parentTrace, "unlock", (trace) async {
      await canUnlock(trace, pin);

      isLocked = false;
      await emitValue(lockChanged, trace, false);
    });
  }

  @action
  Future<void> removeLock(Trace parentTrace) async {
    return await traceWith(parentTrace, "removeLock", (trace) async {
      if (_existingPin == null) return;
      final pin = _existingPin!;
      await unlock(trace, pin);
      _existingPin = null;
      hasPin = false;
      await _persistence.delete(trace, _keyLock);
    });
  }

  @action
  Future<void> autoLock(Trace parentTrace) async {
    return await traceWith(parentTrace, "autoLock", (trace) async {
      if (hasPin) {
        await lock(trace, _existingPin!);
      }
    });
  }

  _autoLockOnBackground(Trace parentTrace) async {
    if (hasPin && _perm.isPrivateDnsEnabled && _account.type.isActive()) {
      return await traceWith(parentTrace, "autoLockOnBackground",
          (trace) async {
        await lock(trace, _existingPin!);
        await _stage.setRoute(trace, "home");
        await _stage.showModal(trace, StageModal.lock);
      });
    }
  }
}
