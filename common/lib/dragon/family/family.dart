import 'dart:async';

import 'package:common/common/model/model.dart';
import 'package:common/core/core.dart';
import 'package:common/dragon/account/controller.dart';
import 'package:common/dragon/auth/controller.dart';
import 'package:common/dragon/device/controller.dart';
import 'package:common/dragon/device/this_device.dart';
import 'package:common/dragon/family/devices.dart';
import 'package:common/dragon/perm/controller.dart';
import 'package:common/dragon/perm/dns_perm.dart';
import 'package:common/dragon/profile/controller.dart';
import 'package:common/dragon/stats/controller.dart';
import 'package:common/lock/lock.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/perm/perm.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:dartx/dartx.dart';
import 'package:mobx/mobx.dart';

part 'family.g.dart';

const String _key = "familyDevice:devices";
const familyLinkBase = "https://go.blokada.org/family/link_device";
const linkTemplate = "$familyLinkBase?token=TOKEN";

class FamilyStore = FamilyStoreBase with _$FamilyStore;

abstract class FamilyStoreBase with Store, Logging, Actor {
  late final _stage = DI.get<StageStore>();
  late final _account = DI.get<AccountStore>();
  late final _lock = DI.get<LockStore>();

  late final _device = DI.get<DeviceController>();
  late final _stats = DI.get<StatsController>();
  late final _auth = DI.get<AuthController>();
  late final _thisDevice = DI.get<ThisDevice>();
  late final _dnsPerm = DI.get<DnsPerm>();
  late final _perm = DI.get<PermController>();
  late final _permStore = DI.get<PermStore>();
  late final _acc = DI.get<AccountController>();
  late final _profiles = DI.get<ProfileController>();

  @override
  onRegister(Act act) {
    DI.register<FamilyStore>(this as FamilyStore);

    if (!(act.isFamily ?? false)) return;

    _acc.start();
    _perm.start(Markers.start);

    _account.addOn(accountChanged, _postActivationOnboarding);
    _lock.addOnValue(lockChanged, _updatePhaseFromLock);

    _onStatsChanges();
    _onDnsPermChanges();

    _device.onChange = (dirty) => log(Markers.device)
        .trace("devicesChanged", (m) => _reload(m, dirty: dirty));

    _auth.onTokenExpired = (m) {
      log(m).i("token expired");
      linkedMode = false;
      linkedTokenOk = false;
      _thisDevice.now = null;
      _updatePhase(m, reason: "tokenExpired");
    };
    _auth.onTokenRefreshed = (m) {
      log(m).i("token refreshed");
      linkedMode = true;
      linkedTokenOk = true;
      _updatePhase(m, reason: "tokenRefreshed");
    };
  }

  @observable
  FamilyPhase phase = FamilyPhase.starting;

  @observable
  bool? accountActive;

  @observable
  bool? permsGranted = false;

  @observable
  bool appLocked = false;

  @observable
  bool linkedMode = false;

  @observable
  bool linkedTokenOk = false;

  @observable
  FamilyDevices devices = FamilyDevices([], null);

  @observable
  String onboardLinkTemplate = linkTemplate;

  LinkingDevice? _linkingDevice;
  var linkDeviceHeartbeatReceived = () {};

  bool _onboardingShown = false;

  // React to stats updates for devices
  _onStatsChanges() {
    _stats.onStatsUpdated = (m) async {
      return await log(m).trace("statsUpdated", (m) async {
        devices = devices.updateStats(_stats.stats);
        _updatePhase(m, reason: "statsChanges");
      });
    };
  }

  _onDnsPermChanges() {
    _dnsPerm.onChange.listen((it) async {
      return await log(Markers.perm).trace("dnsPermChanged", (m) async {
        permsGranted = it;
        _updatePhase(m, reason: "dnsPermChanged");
      });
    });
  }

  @override
  onStart(Marker m) async {
    if (!act.isFamily) return;
    return await log(m).trace("start", (m) async {
      await _reload(m);
      _auth.start(m);
    });
  }

  // First CTA action to either activate onboarding or open payment
  activateCta(Marker m) async {
    return await log(m).trace("activateCta", (m) async {
      if (_account.type.isActive()) {
        _updatePhase(m, loading: true);
        await _reload(m, createDeviceIfNeeded: true);
        _updatePhase(m, loading: false, reason: "activateCta");
        return;
      }
      _permStore.askNotificationPermissions(m);
      _stage.showModal(StageModal.payment, m);
    });
  }

  _reload(Marker m,
      {bool dirty = false, bool createDeviceIfNeeded = false}) async {
    return await log(m).trace("reload", (m) async {
      if (!dirty) {
        await _device.reload(m, createIfNeeded: createDeviceIfNeeded);
      }

      final deviceTag = (await _thisDevice.fetch())?.deviceTag;
      log(m).pair("deviceTag", deviceTag);

      devices = FamilyDevices([], null)
          .fromApi(_device.devices, _profiles.profiles, deviceTag);
      _stats.monitorDeviceTags = devices.getTags();

      await _stats.startAutoRefresh(m);
    });
  }

  // Initiates the QR code based child device registration process,
  // Returns URL to be used in QR code.
  @action
  Future<LinkingDevice> initiateLinkDevice(String deviceName,
      JsonProfile? profile, JsonDevice? device, Marker m) async {
    return await log(m).trace("setWaitingForDevice", (m) async {
      String qrUrl;
      LinkingDevice d = device == null
          ? await _device.addDevice(deviceName, profile, m)
          : LinkingDevice(device: device, relink: true);
      d.token = await _auth.createToken(d.device.deviceTag, m);
      log(m).i("Linking device ${d.device.deviceTag} token: ${d.token}");
      _linkingDevice = d;
      _device.onHeartbeat = (tag) => _finishLinkDevice(m, tag);
      _device.startHeartbeatMonitoring(d.device.deviceTag, m);
      d.qrUrl = _generateLink(d.token);
      return d;
    });
  }

  cancelLinkDevice(Marker m) async {
    return await log(m).trace("cancelAddDevice", (m) async {
      if (_linkingDevice == null) return;
      final d = _linkingDevice!;
      log(m).i("cancelling device ${d.device.deviceTag}");
      if (!d.relink) await _device.deleteDevice(d.device, m);
      _device.stopHeartbeatMonitoring();
      _linkingDevice = null;
    });
  }

  _finishLinkDevice(Marker m, DeviceTag tag) async {
    if (tag == _linkingDevice!.device.deviceTag) {
      _linkingDevice = null;
      _device.stopHeartbeatMonitoring();
      linkDeviceHeartbeatReceived();
      await log(m).trace("reloadAfterLinkDevice", (m) async {
        await _reload(4377);
      });
    } else {
      log(m).e(msg: "addDevice: unexpected device tag: $tag");
    }
  }

  String _generateLink(String token) {
    return onboardLinkTemplate.replaceAll("TOKEN", token.urlEncode);
  }

  @action
  deleteDevice(JsonDevice device, Marker m, {bool isRename = false}) async {
    return await log(m).trace("deleteDevice", (m) async {
      await _device.deleteDevice(device, m);
      await _reload(m);
      // xxxx: not sure if need to do something when deleting thisdevice
    });
  }

  // React to account changes to show the proper onboarding
  @action
  _postActivationOnboarding(Marker m) async {
    log(m).i("postActivationOnboarding");
    accountActive = _account.type.isActive();
    if (accountActive == true) {
      await _reload(m, createDeviceIfNeeded: true);
    }
    _updatePhase(m, reason: "postActivationOnboarding");

    log(m).pair("modal", _stage.route.modal);
    if (_stage.route.modal == StageModal.payment) {
      return await log(m).trace("dismissModalAfterAccountIdChange", (m) async {
        await _stage.dismissModal(m);
      });
    }
  }

  // Locking this device will enable the blocking for "this device"
  @action
  _updatePhaseFromLock(bool isLocked, Marker m) async {
    if (!act.isFamily) return;
    _updatePhase(m, loading: true);
    appLocked = isLocked;

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
    _updatePhase(m, reason: "fromLock");
  }

  link(String qrUrl, Marker m) async {
    return await log(m).trace("link", (m) async {
      try {
        final token = qrUrl.split("?token=").last;
        final deviceTag = await _auth.useToken(token, m);
        log(m).i("received proper token for device: $deviceTag: $token");
        await _device.setThisDeviceForLinked(deviceTag, token, m);
        _auth.startHeartbeat();
        linkedMode = true;
        linkedTokenOk = true;
        await _stage.dismissModal(m);
      } on AlreadyLinkedException catch (e) {
        await _stage.showModal(StageModal.faultLinkAlready, m);
        rethrow;
      } catch (e) {
        await _stage.showModal(StageModal.fault, m);
        rethrow;
      }
    });
  }

  // case: device deleted, show start of the flow, maybe some dialog

  // Show the welcome screen on the first start (family only)
  _maybeShowOnboardOnStart(Marker m) async {
    if (!act.isFamily) return;
    if (_account.type.isActive()) return;
    if (devices.hasDevices == true) return;
    if (linkedMode) return;

    if (_onboardingShown) return;
    _onboardingShown = true;

    return await log(m).trace("showOnboard", (m) async {
      await _stage.showModal(StageModal.onboardingFamily, m);
    });
  }

  Timer? timer;

  // To avoid UI jumping on the state changing quickly with timer
  _updatePhase(Marker m, {bool? loading, String reason = ""}) {
    timer?.cancel();
    log(m).i("Will update phase, reason: $reason");
    if (loading != null) _updatePhaseNow(m, loading);
    timer = Timer(const Duration(seconds: 2), () => _updatePhaseNow(m, false));
  }

  _updatePhaseNow(Marker m, bool loading) {
    if (loading) {
      phase = FamilyPhase.starting;
    } else if (accountActive == null || permsGranted == null) {
      phase = FamilyPhase.starting;
    } else if (linkedMode && permsGranted == true && linkedTokenOk) {
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
        _thisDevice.now == null ||
        !devices.hasThisDevice) {
      phase = FamilyPhase.fresh;
    } else if (/*devices.hasThisDevice && */ permsGranted != true) {
      phase = FamilyPhase.noPerms;
    } else if (devices.hasDevices == true) {
      phase = FamilyPhase.parentHasDevices;
    } else if (devices.hasDevices == false) {
      phase = FamilyPhase.parentNoDevices;
    } else {
      phase = FamilyPhase.starting;
    }

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
