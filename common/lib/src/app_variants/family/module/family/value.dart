part of 'family.dart';

// startable

// activatecta
// deletedevice

// link, cancellink
// linkdeviceheartbeatreceived <- separate actor

class FamilyPhaseValue extends Value<FamilyPhase> {
  FamilyPhaseValue() : super(load: () => FamilyPhase.starting);
}

class FamilyDevicesValue extends Value<FamilyDevices> {
  FamilyDevicesValue() : super(load: () => FamilyDevices([], null), sensitive: true);
}

class ParentDeviceProtectionOwnerValue extends Value<ParentDeviceProtectionOwner> {
  ParentDeviceProtectionOwnerValue() : super(load: () => ParentDeviceProtectionOwner.unknown);
}

class FamilyLinkedMode extends Value<bool> {
  FamilyLinkedMode() : super(load: () => false);
}

/// The enrolment token from an incoming link, parked until the UI is mounted
/// and the user has answered. Deliberately in-memory: a link the user never
/// answered must not survive an app restart.
class PendingLinkValue extends NullableAsyncValue<String> {
  PendingLinkValue() : super(sensitive: true) {
    load = (Marker m) async => null;
  }
}
