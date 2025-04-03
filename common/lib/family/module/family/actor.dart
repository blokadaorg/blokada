part of 'family.dart';

class FamilyActor with Logging, Actor {
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();

  late final _device = Core.get<DeviceActor>();
  late final _stats = Core.get<StatsActor>();
  late final _thisDevice = Core.get<ThisDevice>();
  late final _dnsPerm = Core.get<DnsPerm>();
  late final _permStore = Core.get<PlatformPermActor>();
  late final _profiles = Core.get<ProfileActor>();
  late final _link = Core.get<LinkActor>();
  late final _payment = Core.get<PaymentActor>();

  late final _isLocked = Core.get<IsLocked>();

  late final phase = Core.get<FamilyPhaseValue>();
  late final devices = Core.get<FamilyDevicesValue>();

  // TODO: make them values or private
  bool? accountActive;
  bool? permsGranted = false;
  bool appLocked = false;

  bool _onboardingShown = false;

  @override
  onStart(Marker m) async {
    return await log(m).trace("start", (m) async {
      _account.addOn(accountChanged, _postActivationOnboarding);
      _isLocked.onChange.listen(_updatePhaseFromLock);
      _link.linkedMode.onChange.listen(
          (_) => _updatePhase(Markers.root, reason: "linkedModeChanged"));
      _link.linkDeviceFinished = (m) => _reload(m);

      _onStatsChanges();
      _onDnsPermChanges();

      _device.onChange = (dirty) => log(Markers.device)
          .trace("devicesChanged", (m) => _reload(m, dirty: dirty));

      await _reload(m);
    });
  }

  // React to stats updates for devices
  _onStatsChanges() {
    _stats.onStatsUpdated = (m) async {
      return await log(m).trace("statsUpdated", (m) async {
        devices.now = devices.now.updateStats(_stats.stats);
        _updatePhase(m, reason: "statsChanges");
      });
    };
  }

  _onDnsPermChanges() {
    _dnsPerm.onChangeInstant((it) async {
      return await log(Markers.perm).trace("dnsPermChanged", (m) async {
        permsGranted = it.now;
        _updatePhase(m, reason: "dnsPermChanged");
      });
    });
  }

  // First CTA action to either activate onboarding or open payment
  activateCta(Marker m) async {
    return await log(m).trace("activateCta", (m) async {
      if (_account.type.isActive()) {
        _updatePhase(m, loading: true);
        await _reload(m, createDeviceIfNeeded: true);
        _updatePhase(m, loading: false, reason: "activateCta");
      } else {
        _permStore.askNotificationPermissions(m); // Family only
        await _payment.openPaymentScreen(m);
      }
    });
  }

  _reload(Marker m,
      {bool dirty = false, bool createDeviceIfNeeded = false}) async {
    return await log(m).trace("reload", (m) async {
      if (!dirty) {
        await _device.reload(m, createIfNeeded: createDeviceIfNeeded);
      }

      final deviceTag = (await _thisDevice.fetch(m))?.deviceTag;
      log(m).pair("deviceTag", deviceTag);

      devices.now = FamilyDevices([], null)
          .fromApi(_device.devices, _profiles.profiles, deviceTag);
      _stats.monitorDeviceTags = devices.now.getTags();

      await _stats.startAutoRefresh(m);
    });
  }

  deleteDevice(JsonDevice device, Marker m, {bool isRename = false}) async {
    return await log(m).trace("deleteDevice", (m) async {
      await _device.deleteDevice(device, m);
      await _reload(m);
      // xxxx: not sure if need to do something when deleting thisdevice
    });
  }

  // React to account changes to show the proper onboarding
  _postActivationOnboarding(Marker m) async {
    log(m).i("postActivationOnboarding");
    accountActive = _account.type.isActive();
    if (accountActive == true) {
      await _reload(m, createDeviceIfNeeded: false);
    }
    _updatePhase(m, reason: "postActivationOnboarding");

    log(m).pair("modal", _stage.route.modal);
    _payment.closePaymentScreen(m);
  }

  // Locking this device will enable the blocking for "this device"
  _updatePhaseFromLock(ValueUpdate<bool> isLocked) async {
    if (!Core.act.isFamily) return;
    _updatePhase(Markers.root, loading: true);
    appLocked = isLocked.now;

    // if (isLocked) {
    //   // Locking means that this device is supposed to be active.
    //   // Pop up the perms modal if perms are not granted.
    //   if (!_perm.isPrivateDnsEnabled) {
    //     //await _stage.showModal(parentTrace, StageModal.perms);
    //   }
    //
    //   // Make sure cloud is enabled for this device
    //   if (_device.cloudEnabled == false && accountActive == true) {
    //     await _device.setCloudEnabled(parentTrace, true);
    //   }
    //
    //   // Add "this device" to the list
    //   // if (devices.hasThisDevice == false) {
    //   //   await _addThisDevice(parentTrace);
    //   // }
    // }
    _updatePhase(Markers.root, reason: "fromLock");
  }

  // case: device deleted, show start of the flow, maybe some dialog

  Timer? timer;

  // To avoid UI jumping on the state changing quickly with timer
  _updatePhase(Marker m, {bool? loading, String reason = ""}) {
    timer?.cancel();
    log(m).i("Will update phase, reason: $reason");
    if (loading != null) _updatePhaseNow(m, loading);
    timer = Timer(const Duration(seconds: 2), () => _updatePhaseNow(m, false));
  }

  _updatePhaseNow(Marker m, bool loading) {
    FamilyPhase phase = FamilyPhase.starting;
    final linkedMode = _link.linkedMode.now;
    final linkedTokenOk = _link.linkedTokenOk;

    if (loading) {
      phase = FamilyPhase.starting;
    } else if (accountActive == null || permsGranted == null) {
      phase = FamilyPhase.starting;
    } else if (linkedMode && permsGranted == true && linkedTokenOk) {
      _payment.reportOnboarding(OnboardingStep.permsGranted);
      phase = FamilyPhase.linkedActive;
    } else if (linkedMode && permsGranted == true) {
      phase = FamilyPhase.linkedExpired;
    } else if (linkedMode && !appLocked) {
      phase = FamilyPhase.linkedNoPerms;
    } else if (linkedMode && accountActive == false) {
      // Special case, app is setup in linked mode, but account got expired
      // This is parent account, so child device cannot do much about it.
      // Just display as active on child device.
      // Not sure if necessary still after token introduction
      phase = FamilyPhase.linkedActive;
    } else if (linkedMode) {
      phase = FamilyPhase.linkedNoPerms;
    } else if (appLocked && permsGranted == true) {
      phase = FamilyPhase.lockedActive;
    } else if (appLocked && accountActive == false) {
      phase = FamilyPhase.lockedNoAccount;
    } else if (appLocked) {
      phase = FamilyPhase.lockedNoPerms;
    } else if (accountActive == false ||
        _thisDevice.present == null ||
        !devices.now.hasThisDevice) {
      phase = FamilyPhase.fresh;
      _payment.reportOnboarding(OnboardingStep.freshHomeReached);
    } else if (/*devices.hasThisDevice && */ permsGranted != true) {
      phase = FamilyPhase.noPerms;
    } else if (devices.now.hasDevices == true) {
      _payment.reportOnboarding(OnboardingStep.permsGranted);
      phase = FamilyPhase.parentHasDevices;
    } else if (devices.now.hasDevices == false) {
      phase = FamilyPhase.parentNoDevices;
    } else {
      phase = FamilyPhase.starting;
    }

    this.phase.now = phase;

    log(m).log(msg: "phase updated: $phase", attr: {
      "loading": loading,
      "accountActive": accountActive,
      "permsGranted": permsGranted,
      "appLocked": appLocked,
      "linkedMode": linkedMode,
      "linkedTokenOk": linkedTokenOk,
    });
  }
}
