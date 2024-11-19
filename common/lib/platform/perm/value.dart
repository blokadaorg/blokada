part of 'perm.dart';

class PrivateDnsEnabledFor extends NullableAsyncValue<DeviceTag> {
  PrivateDnsEnabledFor() {
    load = (Marker m) async => null;
  }
}

class NotificationEnabled extends NullableAsyncValue<bool> {
  NotificationEnabled() {
    load = (Marker m) async => false;
  }
}

class VpnEnabled extends NullableAsyncValue<bool> {
  VpnEnabled() {
    load = (Marker m) async => false;
  }
}
