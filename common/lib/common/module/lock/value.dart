part of 'lock.dart';

class IsLocked extends Value<bool> {
  IsLocked() : super(load: () => false);
}

class HasPin extends Value<bool> {
  HasPin() : super(load: () => false);
}

class ExistingPin extends StringPersistedValue {
  ExistingPin() : super("lock:pin");
}
