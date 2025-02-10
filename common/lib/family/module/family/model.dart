part of 'family.dart';

class FamilyDevice {
  final JsonDevice device;
  final JsonProfile profile;
  final UiStats stats;
  final bool thisDevice;
  final bool linked;

  FamilyDevice({
    required this.device,
    required this.profile,
    required this.stats,
    required this.thisDevice,
    required this.linked,
  });
}

extension FamilyDeviceExt on FamilyDevice {
  String get displayName =>
      !thisDevice ? device.alias : "app settings section header".i18n;
}

enum FamilyPhase {
  starting, // Not yet usable state, UI should show loading
  fresh, // No devices, no active account
  noPerms, // Parent mode, app unlocked, but no perms
  linkedExpired, // Linked and perms, but no valid token available
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
        this == FamilyPhase.linkedActive ||
        this == FamilyPhase.linkedExpired;
  }

  bool isLocked2() {
    return this == FamilyPhase.starting ||
        this == FamilyPhase.lockedNoPerms ||
        this == FamilyPhase.lockedNoAccount ||
        this == FamilyPhase.lockedActive ||
        this == FamilyPhase.linkedNoPerms ||
        this == FamilyPhase.linkedActive;
  }

  bool requiresAction() {
    return this == FamilyPhase.fresh ||
        this == FamilyPhase.noPerms ||
        this == FamilyPhase.linkedNoPerms ||
        this == FamilyPhase.parentNoDevices ||
        this == FamilyPhase.lockedNoPerms ||
        this == FamilyPhase.lockedNoAccount;
  }

  bool hasBottomBar() {
    return requiresAction() ||
        this == FamilyPhase.parentHasDevices ||
        this == FamilyPhase.linkedActive ||
        this == FamilyPhase.lockedActive;
  }

  bool requiresBigCta() {
    return this == FamilyPhase.fresh ||
        this == FamilyPhase.noPerms ||
        this == FamilyPhase.linkedNoPerms ||
        this == FamilyPhase.parentNoDevices ||
        this == FamilyPhase.lockedActive ||
        this == FamilyPhase.lockedNoPerms ||
        this == FamilyPhase.lockedNoAccount ||
        this == FamilyPhase.linkedExpired;
  }

  bool requiresPerms() {
    return this == FamilyPhase.noPerms ||
        this == FamilyPhase.linkedNoPerms ||
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
        this == FamilyPhase.lockedActive ||
        this == FamilyPhase.noPerms;
  }

  bool isLinkable() {
    return this == FamilyPhase.fresh ||
        this == FamilyPhase.starting ||
        this == FamilyPhase.noPerms ||
        this == FamilyPhase.parentNoDevices;
  }

  bool isLockable() {
    return this == FamilyPhase.linkedActive ||
        this == FamilyPhase.linkedNoPerms ||
        //this == FamilyPhase.linkedUnlocked ||
        this == FamilyPhase.lockedActive ||
        this == FamilyPhase.lockedNoPerms;
    //this == FamilyPhase.parentHasDevices ||
    //this == FamilyPhase.noPerms;
  }
}

class LinkingDevice {
  final JsonDevice device;
  final bool relink;
  final JsonProfile? profile;
  late String token;
  late String qrUrl;

  LinkingDevice({
    required this.device,
    this.relink = false,
    this.profile,
  });
}
