import 'package:common/core/core.dart';

class IsLocked extends Value<bool> {}

class HasPin extends Value<bool> {}

class ExistingPin extends StringPersistedValue {
  @override
  String get key => "lock:pin";
}
