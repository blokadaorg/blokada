part of 'perm.dart';

class PrivateDnsEnabledForValue extends NullableAsyncValue<DeviceTag> {
  PrivateDnsEnabledForValue() {
    load = (Marker m) async => null;
  }
}

class NotificationEnabledValue extends NullableAsyncValue<bool> {
  NotificationEnabledValue() {
    load = (Marker m) async => false;
  }
}

class VpnEnabledValue extends NullableAsyncValue<bool> {
  VpnEnabledValue() {
    load = (Marker m) async => false;
  }
}
