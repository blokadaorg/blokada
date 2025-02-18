part of 'device.dart';

class CurrentToken extends StringPersistedValue {
  CurrentToken() : super("linked_status");
}

class SelectedDeviceTag extends NullableAsyncValue<DeviceTag> {
  SelectedDeviceTag() : super(sensitive: true) {
    load = (Marker m) async => null;
  }
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
