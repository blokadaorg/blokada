import '../stats/stats.dart';

class FamilyDevice {
  final String deviceName;
  final String deviceDisplayName;
  final UiStats stats;
  final bool thisDevice;

  FamilyDevice({
    required this.deviceName,
    required this.deviceDisplayName,
    required this.stats,
    required this.thisDevice,
  });
}

enum FamilyPhase {
  starting, // Not yet usable state, UI should show loading
  fresh, // No devices, no active account
  linkedNoPerms, // Linked as child device, no DNS setup yet
  linkedActive, // Linked and all good
  parentNoDevices, // Active account, nothing set up yet
  parentHasDevices, // Active account, at least one device setup
  lockedNoPerms, // Device is locked (parent device in child mode), no DNS perms
  lockedNoAccount, // Device is locked (parent device in child mode), account expired
  lockedActive, // Device is locked and perms good to go
}

extension FamilyPhaseExt on FamilyPhase {
  bool isLocked() {
    return this == FamilyPhase.starting ||
        this == FamilyPhase.fresh ||
        this == FamilyPhase.parentNoDevices ||
        this == FamilyPhase.lockedNoPerms ||
        this == FamilyPhase.lockedNoAccount ||
        this == FamilyPhase.lockedActive ||
        this == FamilyPhase.linkedNoPerms ||
        this == FamilyPhase.linkedActive;
  }

  bool requiresAction() {
    return this == FamilyPhase.fresh ||
        this == FamilyPhase.linkedNoPerms ||
        this == FamilyPhase.parentNoDevices ||
        this == FamilyPhase.lockedNoPerms ||
        this == FamilyPhase.lockedNoAccount;
  }

  bool requiresPerms() {
    return this == FamilyPhase.linkedNoPerms ||
        this == FamilyPhase.lockedNoPerms;
  }

  bool requiresActivation() {
    return this == FamilyPhase.fresh || this == FamilyPhase.lockedNoAccount;
  }

  bool isParent() {
    return this == FamilyPhase.parentNoDevices ||
        this == FamilyPhase.parentHasDevices ||
        this == FamilyPhase.lockedNoPerms ||
        this == FamilyPhase.lockedNoAccount ||
        this == FamilyPhase.lockedActive;
  }

  bool isLinkable() {
    return this == FamilyPhase.fresh ||
        this == FamilyPhase.starting ||
        this == FamilyPhase.parentNoDevices;
  }
}
