part of '../model.dart';

class FamilyDevice {
  final String deviceName;
  final String deviceDisplayName;
  final UiStats stats;
  final bool thisDevice;
  final bool enabled;
  final bool configured;

  FamilyDevice({
    required this.deviceName,
    required this.deviceDisplayName,
    required this.stats,
    required this.thisDevice,
    required this.enabled,
    required this.configured,
  });
}

enum FamilyPhase {
  starting, // Not yet usable state, UI should show loading
  fresh, // No devices, no active account
  noPerms, // Parent mode, app unlocked, but no perms
  linkedUnlocked, // Linked and perms, but not locked or no PIN set
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
        this == FamilyPhase.linkedUnlocked;
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

  bool requiresBobo() {
    return this == FamilyPhase.fresh ||
        this == FamilyPhase.noPerms ||
        this == FamilyPhase.linkedNoPerms ||
        this == FamilyPhase.parentNoDevices ||
        this == FamilyPhase.linkedActive ||
        this == FamilyPhase.lockedActive ||
        this == FamilyPhase.lockedNoPerms ||
        this == FamilyPhase.lockedNoAccount ||
        this == FamilyPhase.linkedUnlocked;
  }

  bool hideTabs() {
    return this == FamilyPhase.fresh ||
        this == FamilyPhase.noPerms ||
        this == FamilyPhase.linkedNoPerms ||
        this == FamilyPhase.starting ||
        this == FamilyPhase.linkedActive ||
        this == FamilyPhase.lockedActive ||
        this == FamilyPhase.lockedNoPerms ||
        this == FamilyPhase.lockedNoAccount ||
        this == FamilyPhase.linkedUnlocked;
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
