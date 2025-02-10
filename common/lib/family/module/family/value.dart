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
  FamilyDevicesValue() : super(load: () => FamilyDevices([], null));
}

class FamilyLinkedMode extends Value<bool> {
  FamilyLinkedMode() : super(load: () => false);
}
