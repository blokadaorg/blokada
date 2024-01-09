import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dartx/dartx.dart';
import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../app/app.dart';
import '../app/start/start.dart';
import '../device/device.dart';
import '../journal/journal.dart';
import '../lock/lock.dart';
import '../perm/perm.dart';
import '../persistence/persistence.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../stats/refresh/refresh.dart';
import '../stats/stats.dart';
import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'devices.dart';
import 'json.dart';
import 'model.dart';

part 'family.g.dart';

const String _key = "familyDevice:devices";
const familyLinkBase = "https://go.blokada.org/family/link_device";
const linkTemplate = "$familyLinkBase?tag=TAG&name=NAME";

class FamilyStore = FamilyStoreBase with _$FamilyStore;

abstract class FamilyStoreBase
    with Store, Traceable, TraceOrigin, Dependable, Startable {
  late final _ops = dep<FamilyOps>();
  late final _persistence = dep<PersistenceService>();
  late final _stage = dep<StageStore>();
  late final _account = dep<AccountStore>();
  late final _lock = dep<LockStore>();
  late final _cloudDevice = dep<DeviceStore>();
  late final _journal = dep<JournalStore>();
  late final _device = dep<DeviceStore>();
  late final _stats = dep<StatsStore>();
  late final _statsRefresh = dep<StatsRefreshStore>();
  late final _perm = dep<PermStore>();

  FamilyStoreBase() {
    _account.addOn(accountChanged, _postActivationOnboarding);
    _lock.addOnValue(lockChanged, _updatePhaseFromLock);
    _device.addOn(deviceChanged, _syncLinkedMode);

    // TODO: this pattern is probably unwanted
    _onDevicesChanged();
    _onJournalChanges();
    _onStatsChanges();
    _onThisDeviceNameChange();
    _onDnsPermChanges();
    _onDnsForwardChanges();
    _onPhaseShowNavbar();
  }

  @override
  attach(Act act) {
    depend<FamilyOps>(getOps(act));
    depend<FamilyStore>(this as FamilyStore);
  }

  @observable
  FamilyPhase phase = FamilyPhase.starting;

  @observable
  bool? accountActive;

  @observable
  bool? permsGranted;

  @observable
  bool? dnsForwarding;

  @observable
  bool appLocked = false;

  @observable
  bool linkedMode = false;

  @observable
  FamilyDevices devices = FamilyDevices([], null);

  String? _waitingForDevice;

  bool _onboardingShown = false;

  _onDevicesChanged() {
    reactionOnStore((_) => devices, (devices) async {
      return await traceAs("onDevicesChanged", (trace) async {
        await _statsRefresh.setMonitoredDevices(trace, devices.getNames());
        await _savePersistence(trace);
        _updatePhase();
        _updateDnsForward(devices.entries);
      });
    });
  }

  _onJournalChanges() {
    reactionOnStore((_) => _journal.allEntries, (entries) async {
      return await traceAs("onJournalChanged", (trace) async {
        await _discoverEntries(trace);
      });
    });
  }

  // React to stats updates for devices
  _onStatsChanges() {
    reactionOnStore((_) => _stats.deviceStatsChangesCounter, (_) async {
      for (final entry in _stats.deviceStats.entries) {
        devices = devices.updateStats(entry.key, entry.value);
      }
    });
  }

  // React to this device name changes
  _onThisDeviceNameChange() {
    reactionOnStore((_) => _device.deviceAlias, (alias) async {
      devices = devices.updateThisDeviceName(alias);
    });
  }

  _onDnsPermChanges() {
    reactionOnStore((_) => _perm.privateDnsEnabledFor, (enabled) async {
      permsGranted = _perm.isPrivateDnsEnabled;
      _updatePhase();
    });
  }

  _onDnsForwardChanges() {
    reactionOnStore((_) => _perm.isForwardDns, (enabled) async {
      dnsForwarding = _perm.isForwardDns;
      _updatePhase();
    });
  }

  _onPhaseShowNavbar() {
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
      await _load(trace);
    });
  }

  @action
  _load(Trace parentTrace) async {
    return await traceWith(parentTrace, "load", (trace) async {
      final json = await _persistence.load(trace, _key);
      if (json == null) return;

      devices = FamilyDevices([], null).fromNames(
          JsonFamilyDevices.fromJson(jsonDecode(json)).devices,
          _device.deviceAlias);

      _updateDnsForward(devices.entries);
    });
  }

  _savePersistence(Trace trace) async {
    await _persistence.save(
        trace, _key, JsonFamilyDevices.fromList(devices.entries).toJson());
  }

  // Links a supervised device to the account
  @action
  link(Trace parentTrace, String tag, String name) async {
    if (!act.isFamily()) return;
    return await traceWith(parentTrace, "link", (trace) async {
      if (!phase.isLinkable()) throw Exception("Device not linkable anymore");
      _updatePhase(loading: true);
      await _cloudDevice.setDeviceAlias(trace, name);
      await _cloudDevice.setLinkedTag(trace, tag);
      await _stage.showModal(trace, StageModal.lock);
    });
  }

  @action
  unlink(Trace parentTrace) async {
    if (!act.isFamily()) return;
    return await traceWith(parentTrace, "unlink", (trace) async {
      if (phase != FamilyPhase.linkedUnlocked) throw Exception("Cannot unlink");
      _updatePhase(loading: true);
      await _cloudDevice.setLinkedTag(trace, null);
    });
  }

  @action
  addDevice(Trace parentTrace, String deviceAlias, UiStats stats) async {
    return await traceWith(parentTrace, "addDevice", (trace) async {
      _waitingForDevice = null;
      devices = devices.addDevice(deviceAlias, stats);
      await _journal.updateJournalFreq(trace); // To refresh immediately
    });
  }

  @action
  deleteDevice(Trace parentTrace, String deviceAlias,
      {bool isRename = false}) async {
    return await traceWith(parentTrace, "deleteDevice", (trace) async {
      _waitingForDevice = null;
      final thisDevice = devices.hasDevice(deviceAlias, thisDevice: true);

      if (thisDevice && !isRename) {
        await _lock.removeLock(trace);
      }

      devices = devices.deleteDevice(deviceAlias);
    });
  }

  @action
  deleteAllDevices(Trace parentTrace) async {
    return await traceWith(parentTrace, "deleteAllDevices", (trace) async {
      _waitingForDevice = null;
      devices = FamilyDevices([], false);
      await _savePersistence(trace);
      await _statsRefresh.setMonitoredDevices(trace, []);
    });
  }

  @action
  _syncLinkedMode(Trace parentTrace) async {
    return await traceWith(parentTrace, "syncLinkedMode", (trace) async {
      final tag = _cloudDevice.deviceTag;
      if (tag == null) return;
      final link = linkTemplate.replaceAll("TAG", tag);
      await _ops.doFamilyLinkTemplateChanged(link);
      linkedMode = _cloudDevice.tagOverwritten;
      _updatePhase();
      await _maybeShowOnboardOnStart(trace);
    });
  }

  // React to account changes to show the proper onboarding
  @action
  _postActivationOnboarding(Trace parentTrace) async {
    accountActive = _account.type.isActive();
    _updatePhase();

    if (!act.isFamily()) {
      if (!_account.type.isActive()) return;
      // Old flow for the main flavor, just show the onboarding modal
      // TODO: move elsewhere, it's notfamily
      return await traceWith(parentTrace, "onboardProceed", (trace) async {
        await _stage.showModal(trace, StageModal.perms);
      });
    } else {
      if (_stage.route.modal == StageModal.payment) {
        await traceWith(parentTrace, "dismissModalAfterAccountIdChange",
            (trace) async {
          await _stage.dismissModal(trace);
        });
      }
    }
  }

  // Locking this device will enable the blocking for "this device"
  @action
  _updatePhaseFromLock(Trace parentTrace, bool isLocked) async {
    if (!act.isFamily()) return;
    _updatePhase(loading: true);
    appLocked = isLocked;

    if (isLocked) {
      // Locking means that this device is supposed to be active.
      // Pop up the perms modal if perms are not granted.
      if (!_perm.isPrivateDnsEnabled) {
        await _stage.showModal(parentTrace, StageModal.perms);
      }

      // Make sure cloud is enabled for this device
      if (_device.cloudEnabled == false && accountActive == true) {
        await _device.setCloudEnabled(parentTrace, true);
      }

      // Add "this device" to the list
      if (devices.hasThisDevice == false) {
        await _addThisDevice(parentTrace);
      }
    }
    _updatePhase();
  }

  @action
  Future<void> renameThisDevice(Trace parentTrace, String newDeviceName) async {
    return await traceWith(parentTrace, "renameThisDevice", (trace) async {
      final name = newDeviceName.trim();
      if (devices.hasDevice(name, thisDevice: false)) {
        throw Exception("Device $name already exists");
      }
      if (name.isEmpty) throw Exception("Name cannot be empty");
      trace.addAttribute("name", name);

      await deleteDevice(trace, _device.deviceAlias, isRename: true);
      await _device.setDeviceAlias(trace, name);
      await _addThisDevice(trace);
      await _stage.setRoute(trace, "home"); // Reset to main tab
    });
  }

  _addThisDevice(Trace parentTrace) async {
    return await traceWith(parentTrace, "addThisDevice", (trace) async {
      final stats = _stats.deviceStats[_device.deviceAlias] ?? UiStats.empty();
      devices = devices.addThisDevice(_device.deviceAlias, stats);
    });
  }

  @action
  setWaitingForDevice(Trace parentTrace, String deviceName) async {
    return await traceWith(parentTrace, "setWaitingForDevice", (trace) async {
      _waitingForDevice = deviceName.trim();
    });
  }

  // Show the welcome screen on the first start (family only)
  _maybeShowOnboardOnStart(Trace parentTrace) async {
    if (_account.type.isActive()) return;
    if (devices.hasDevices == true) return;
    if (linkedMode) return;

    if (_onboardingShown) return;
    _onboardingShown = true;

    return await traceWith(parentTrace, "showOnboard", (trace) async {
      await _stage.showModal(trace, StageModal.onboardingFamily);
    });
  }

  _discoverEntries(Trace parentTrace) async {
    return await traceWith(parentTrace, "discoverEntries", (trace) async {
      // Map of device name to stats
      final known = Map.fromEntries(_journal.devices
          .map((e) => MapEntry(
              e, _stats.deviceStats.getOrElse(e, () => UiStats.empty())))
          .toList());

      devices = devices.fromStats(known);

      // Discover a new device in stats, if we are expecting one
      final newDeviceName = _waitingForDevice;
      if (newDeviceName != null && known.containsKey(newDeviceName)) {
        await addDevice(trace, newDeviceName, known[newDeviceName]!);

        // We are waiting on the accountLink sheet, close it
        await _stage.dismissModal(trace);
      }
    });
  }

  _updateDnsForward(List<FamilyDevice> d) {
    // If "this device" is used for blocking, use proper dns
    // Otherwise use forward dns
    final shouldForward = d.firstWhereOrNull((e) => e.thisDevice) == null;
    if (shouldForward == _perm.isForwardDns) return;

    traceAs("updateDnsForward", (trace) async {
      trace.addAttribute("forward", shouldForward);
      await _perm.setForwardDns(trace, shouldForward);
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
    } else if (accountActive ==
            null /* ||
        permsGranted == null ||
        dnsForwarding == null*/
        ) {
      phase = FamilyPhase.starting;
    } else if (linkedMode &&
        permsGranted == true &&
        dnsForwarding == false &&
        appLocked) {
      phase = FamilyPhase.linkedActive;
    } else if (linkedMode && permsGranted == true && dnsForwarding == false) {
      phase = FamilyPhase.linkedUnlocked;
    } else if (linkedMode && !appLocked) {
      phase = FamilyPhase.linkedNoPerms;
    } else if (linkedMode && accountActive == false) {
      // Special case, app is setup in linked mode, but account got expired
      // This is parent account, so child device cannot do much about it.
      // Just display as active on child device.
      phase = FamilyPhase.linkedActive;
    } else if (linkedMode) {
      phase = FamilyPhase.linkedNoPerms;
    } else if (appLocked && permsGranted == true && dnsForwarding == false) {
      phase = FamilyPhase.lockedActive;
    } else if (appLocked && accountActive == false) {
      phase = FamilyPhase.lockedNoAccount;
    } else if (appLocked) {
      phase = FamilyPhase.lockedNoPerms;
    } else if (accountActive == false) {
      phase = FamilyPhase.fresh;
    } else if (devices.hasThisDevice && permsGranted != true) {
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
    });
  }
}
