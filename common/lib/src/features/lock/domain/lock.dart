import 'package:common/src/core/core.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';

part 'actor.dart';

class IsLocked extends Value<bool> {
  IsLocked() : super(load: () => false);
}

class HasPin extends Value<bool> {
  HasPin() : super(load: () => false);
}

class ExistingPin extends StringPersistedValue {
  ExistingPin() : super("lock:pin");
}

/// Whether [pin] has the shape the lock screen and Settings accept: exactly
/// four digits. Shared so the screen that takes the input can explain a bad
/// PIN before handing it to [LockActor], which rejects it as well. Not
/// `isNumeric`, which also accepts a leading minus such as "-123".
bool isValidPin(String pin) => _pinFormat.hasMatch(pin);

final _pinFormat = RegExp(r'^[0-9]{4}$');

/// Thrown by [LockActor] for a PIN that fails [isValidPin]. The caller that
/// took the input shows the error in Flutter: neither native platform renders
/// an alert for it, and raising one through the stage would leave the modal
/// slot taken until the next tab change.
class InvalidPinException implements Exception {
  @override
  String toString() => "InvalidPinException: a PIN must be exactly 4 digits";
}

class LockModule with Module {
  @override
  onCreateModule() async {
    await register(IsLocked());
    await register(HasPin());
    await register(ExistingPin());
    await register(LockActor());
  }
}
