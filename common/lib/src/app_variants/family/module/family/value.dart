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
