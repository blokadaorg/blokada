part of 'device.dart';

class CurrentToken extends StringPersistedValue {
  CurrentToken() : super("linked_status");
}

class SelectedDeviceTag extends NullableAsyncValue<DeviceTag> {
  SelectedDeviceTag() : super(sensitive: true) {
    load = (Marker m) async => null;
  }
}

/// True once this device has been set up, as a linked child or as a parent
/// with its own controller device. Never cleared on token expiry, so a wiped
/// token cannot make a set up device look fresh to the link confirmation.
class WasSetUp extends BoolPersistedValue {
  WasSetUp() : super("was_set_up");
}

class SlidableOnboarding extends BoolPersistedValue {
  SlidableOnboarding() : super("slidable_onboarding");
}

class ThisDevice extends JsonPersistedValue<JsonDevice> {
  ThisDevice() : super("this_device");

  @override
  JsonDevice fromJson(Map<String, dynamic> json) => JsonDevice.fromJson(json);

  @override
  Map<String, dynamic> toJson(JsonDevice value) => value.toJson();
}
