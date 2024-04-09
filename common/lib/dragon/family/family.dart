import 'dart:async';

import 'package:common/account/account.dart';
import 'package:common/common/model.dart';
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
import 'package:common/stage/channel.pg.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:common/util/mobx.dart';
import 'package:common/util/trace.dart';
import 'package:dartx/dartx.dart';
import 'package:mobx/mobx.dart';

part 'family.g.dart';

const String _key = "familyDevice:devices";
const familyLinkBase = "https://go.blokada.org/family/link_device";
const linkTemplate = "$familyLinkBase?token=TOKEN";

class FamilyStore = FamilyStoreBase with _$FamilyStore;

abstract class FamilyStoreBase
    with Store, Traceable, TraceOrigin, Dependable, Startable {
  late final _stage = dep<StageStore>();
  late final _account = dep<AccountStore>();
  late final _lock = dep<LockStore>();

  late final _device = dep<DeviceController>();
  late final _stats = dep<StatsController>();
  late final _auth = dep<AuthController>();
  late final _thisDevice = dep<ThisDevice>();
  late final _dnsPerm = dep<DnsPerm>();
  late final _perm = dep<PermController>();
  late final _acc = dep<AccountController>();
  late final _profiles = dep<ProfileController>();

  @override
  attach(Act act) {
    depend<FamilyStore>(this as FamilyStore);

    if (!(act.isFamily() ?? false)) return;

    _acc.start();
    _perm.start();

    _account.addOn(accountChanged, _postActivationOnboarding);
    _lock.addOnValue(lockChanged, _updatePhaseFromLock);

    _onStatsChanges();
    _onDnsPermChanges();
    _onPhaseShowNavbar(act);

    _device.onChange =
        () => traceAs("devicesChanged", (trace) => _reload(trace));

    _auth.onTokenExpired = () {
      print("token expired");
      linkedMode = true;
      linkedTokenOk = false;
      // traceAs("relinkQr", (trace) async {
      //   await _stage.showModal(trace, StageModal.accountChange);
      // });
      _updatePhase();
    };
    _auth.onTokenRefreshed = () {
      print("token refreshed");
      linkedMode = true;
      linkedTokenOk = true;
      _updatePhase();
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

  JsonDevice? _addingDevice;
  String _addingDeviceToken = "";
  var addingDeviceHeartbeatReceived = () {};

  bool _onboardingShown = false;

  // React to stats updates for devices
  _onStatsChanges() {
    _stats.onStatsUpdated = () {
      devices = devices.updateStats(_stats.stats);
      _updatePhase();
    };
  }

  _onDnsPermChanges() {
    _dnsPerm.onChange.listen((it) {
      permsGranted = it;
      _updatePhase();
    });
  }

  _onPhaseShowNavbar(Act? act) {
    final a = act ?? this.act;
    if (!a.isFamily()) return;
    reactionOnStore((_) => phase, (phase) async {
      return await traceAs("onPhaseShowNavbar", (trace) async {
        await _stage.setShowNavbar(trace, !phase.isLocked());
      });
    });
  }

  @override
  start(Trace parentTrace) async {
    if (!act.isFamily()) return;
    return await traceWith(parentTrace, "start", (trace) async {
      await _reload(trace);
      _auth.start();
    });
  }

  _reload(Trace parentTrace) async {
    return await traceWith(parentTrace, "reload", (trace) async {
      await _device.reload(createIfNeeded: _account.type.isActive());

      devices = FamilyDevices([], null).fromApi(_device.devices,
          _profiles.profiles, (await _thisDevice.fetch())?.deviceTag);
      _stats.monitorDeviceTags = devices.getTags();

      _refreshStats();
    });
  }

  _refreshStats() async {
    await _stats.startAutoRefresh();
    // TODO: stop auto refresh when on bg
  }

  // Initiates the QR code based child device registration process,
  // Returns URL to be used in QR code.
  @action
  Future<AddingDevice> initiateAddDevice(
      Trace parentTrace, String deviceName, JsonProfile? profile) async {
    return await traceWith(parentTrace, "setWaitingForDevice", (trace) async {
      String qrUrl;
      AddingDevice d = await _device.addDevice(deviceName, profile);
      _addingDeviceToken = await _auth.createToken(d.device.deviceTag);
      print("Adding device token: $_addingDeviceToken");
      _addingDevice = d.device;
      _device.onHeartbeat = _finishAddDevice;
      _device.startHeartbeatMonitoring(d.device.deviceTag);
      d.qrUrl = _generateLink(_addingDeviceToken);
      return d;
    });
  }

  cancelAddDevice(Trace parentTrace) async {
    return await traceWith(parentTrace, "cancelAddDevice", (trace) async {
      if (_addingDevice == null) return;
      print("cancelling device ${_addingDevice?.deviceTag}");
      await _device.deleteDevice(_addingDevice!);
      _device.stopHeartbeatMonitoring();
      _addingDevice = null;
    });
  }

  _finishAddDevice(DeviceTag tag) {
    if (tag == _addingDevice!.deviceTag) {
      _addingDevice = null;
      _device.stopHeartbeatMonitoring();
      addingDeviceHeartbeatReceived();
      traceAs("reloadAfterDeviceAdded", (trace) async {
        await _reload(trace);
      });
    } else {
      print("addDevice: unexpected device tag: $tag");
    }
  }

  String _generateLink(String token) {
    return onboardLinkTemplate.replaceAll("TOKEN", token.urlEncode);
  }

  @action
  deleteDevice(Trace parentTrace, JsonDevice device,
      {bool isRename = false}) async {
    return await traceWith(parentTrace, "deleteDevice", (trace) async {
      await _device.deleteDevice(device);
      await _reload(trace);
      // xxxx: not sure if need to do something when deleting thisdevice
    });
  }

  // React to account changes to show the proper onboarding
  @action
  _postActivationOnboarding(Trace parentTrace) async {
    accountActive = _account.type.isActive();
    if (accountActive == true) await _reload(parentTrace);
    _updatePhase();

    if (_stage.route.modal == StageModal.payment) {
      await traceWith(parentTrace, "dismissModalAfterAccountIdChange",
          (trace) async {
        await _stage.dismissModal(trace);
      });
    }
  }

  // Locking this device will enable the blocking for "this device"
  @action
  _updatePhaseFromLock(Trace parentTrace, bool isLocked) async {
    if (!act.isFamily()) return;
    _updatePhase(loading: true);
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
    _updatePhase();
  }

  link(String qrUrl) async {
    try {
      final token = qrUrl.split("?token=").last;
      print("received token: $token");
      final deviceTag = await _auth.useToken(token);
      await _device.setThisDeviceForLinked(deviceTag, token);
      linkedMode = true;
      linkedTokenOk = true;
      traceAs("dismissAfterLink", (trace) async {
        await _stage.dismissModal(trace);
      });
    } catch (e) {
      // case: token failed to refresh, invalid, show qr scan prompt
      // devicetag: perm store, journal store list resolve
      // maybe devicealias in journal and perms
      print("Failed to link: $e");
      rethrow;
    }
  }

  // case: device deleted, show start of the flow, maybe some dialog

  // Show the welcome screen on the first start (family only)
  _maybeShowOnboardOnStart(Trace parentTrace) async {
    if (!act.isFamily()) return;
    if (_account.type.isActive()) return;
    if (devices.hasDevices == true) return;
    if (linkedMode) return;

    if (_onboardingShown) return;
    _onboardingShown = true;

    return await traceWith(parentTrace, "showOnboard", (trace) async {
      await _stage.showModal(trace, StageModal.onboardingFamily);
    });
  }

  Timer? timer;

  // To avoid UI jumping on the state changing quickly with timer
  _updatePhase({bool loading = false}) {
    timer?.cancel();
    if (loading) _updatePhaseNow(true);
    timer = Timer(const Duration(seconds: 1), () => _updatePhaseNow(false));
  }

  _updatePhaseNow(bool loading) {
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
    } else if (accountActive == false) {
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

    traceAs("updatePhase", (trace) async {
      trace.addAttribute("phase", phase);
      trace.addAttribute("loading", loading);
      trace.addAttribute("accountActive", accountActive);
      trace.addAttribute("permsGranted", permsGranted);
      trace.addAttribute("appLocked", appLocked);
      trace.addAttribute("linkedMode", linkedMode);
      trace.addAttribute("hasDevices", devices.hasDevices);
      trace.addAttribute("hasThisDevice", devices.hasThisDevice);
    });
  }
}
