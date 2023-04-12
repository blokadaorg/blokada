import 'package:mobx/mobx.dart';

import '../app/app.dart';
import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.pg.dart';

part 'stage.g.dart';

enum StageTab { unknown, home, activity, advanced, settings }

enum StageModal {
  none,
  fault,
  accountInitFailed,
  accountExpired,
  accountRestoreFailed,
  accountActivated,
  onboarding,
  pause,
  stats,
  help,
  payment,
  paymentDetails,
  plusLocationSelect,
  debug,
  debugLog,
  debugLogShare,
  adsCounter,
  adsCounterShare,
  rateApp,
  updatePrompt,
  updateOngoing,
  updateComplete
}

class StageWaitingEvent {
  final String name;
  final dynamic payload;

  StageWaitingEvent(this.name, this.payload);
}

const _modalDismissCooldownTime = Duration(seconds: 3);

/// StageStore
///
/// Manages app stage, which consists of:
/// - App foreground state
/// - Currently active tab (home, activity, etc)
/// - Tab-specific navigation payload (e.g. selected activity detail)
/// - Currently displayed modal (none, error, etc)
///
/// Manages modals, which are used to display information to the user.
/// Modals take user attention by being displayed on top of the app. User cannot
/// interact with the app until the modal is dismissed. Only one modal can be
/// displayed at a time.

class StageStore = StageStoreBase with _$StageStore;

abstract class StageStoreBase with Store, Traceable {
  final List<StageModal> _modalQueue = [];

  @observable
  bool isForeground = false;

  @observable
  StageTab activeTab = StageTab.unknown;

  @observable
  String? tabPayload;

  @observable
  StageModal modal = StageModal.none;

  DateTime? _lastDismissTimestamp;

  // Queue up events that happened before the app was initialized, for later.
  @observable
  bool isReady = false;

  @observable
  List<StageWaitingEvent> _waitingEvents = [];

  @action
  Future<void> setForeground(Trace parentTrace, bool isForeground) async {
    return await traceWith(parentTrace, "setForeground", (trace) async {
      if (this.isForeground != isForeground) {
        if (!isReady) {
          _waitingEvents.add(StageWaitingEvent("setForeground", isForeground));
          trace.addEvent("event queued");
          return;
        }
        this.isForeground = isForeground;
      }
    });
  }

  @action
  Future<void> setActiveTab(Trace parentTrace, StageTab activeTab) async {
    return await traceWith(parentTrace, "setActiveTab", (trace) async {
      if (this.activeTab != activeTab) {
        if (!isReady) {
          _waitingEvents.add(StageWaitingEvent("setActiveTab", activeTab));
          trace.addEvent("event queued");
          return;
        }
        this.activeTab = activeTab;
        tabPayload = null;
      }
    });
  }

  @action
  Future<void> setTabPayload(Trace parentTrace, String? tabPayload) async {
    return await traceWith(parentTrace, "setTabPayload", (trace) async {
      if (this.tabPayload != tabPayload) {
        if (!isReady) {
          _waitingEvents.add(StageWaitingEvent("setTabPayload", tabPayload));
          trace.addEvent("event queued");
          return;
        }
        this.tabPayload = tabPayload;
      }
    });
  }

  @action
  Future<void> showModalNow(Trace parentTrace, StageModal modal) async {
    return await traceWith(parentTrace, "showModalNow", (trace) async {
      this.modal = modal;
      _lastDismissTimestamp = DateTime.now();
      _modalQueue.clear();
    });
  }

  @action
  Future<void> queueModal(Trace parentTrace, StageModal modal) async {
    return await traceWith(parentTrace, "queueModal", (trace) async {
      _modalQueue.add(modal);
      if (this.modal == StageModal.none) {
        this.modal = _modalQueue.removeAt(0);
        _lastDismissTimestamp = DateTime.now();
      }
    });
  }

  @action
  Future<void> dismissModal(Trace parentTrace,
      {bool byPlatform = false}) async {
    return await traceWith(parentTrace, "dismissModal", (trace) async {
      if (modal != StageModal.none) {
        trace.addAttribute("byPlatform", byPlatform);

        final last = _lastDismissTimestamp;
        if (byPlatform &&
            last != null &&
            last.add(_modalDismissCooldownTime).isAfter(DateTime.now())) {
          // Ignore this platform callback since it's likely a duplicate
          trace.addEvent("dismiss ignored");
          return;
        } else {
          modal = StageModal.none;
          _lastDismissTimestamp = DateTime.now();
        }
      }

      if (_modalQueue.isNotEmpty) {
        modal = _modalQueue.removeAt(0);
      }
    });
  }

  @action
  Future<void> setReady(Trace parentTrace, bool isReady) async {
    return await traceWith(parentTrace, "setReady", (trace) async {
      if (this.isReady == isReady) {
        return;
      }
      this.isReady = isReady;
      if (isReady && _waitingEvents.isNotEmpty) {
        // Process queued events when the app is ready
        trace.addAttribute("queueProcessed", _waitingEvents.length);
        for (final event in _waitingEvents) {
          switch (event.name) {
            case "setForeground":
              await setForeground(trace, event.payload as bool);
              break;
            case "setActiveTab":
              await setActiveTab(trace, event.payload as StageTab);
              break;
            case "setTabPayload":
              await setTabPayload(trace, event.payload as String?);
              break;
          }
        }
        _waitingEvents = [];
      }
    });
  }
}

class StageBinder extends StageEvents with Traceable {
  late final _store = di<StageStore>();
  late final _ops = di<StageOps>();
  late final _app = di<AppStore>();

  StageBinder() {
    StageEvents.setup(this);
    _onModal();
    _onNavPath();
  }

  StageBinder.forTesting() {
    _onModal();
    _onNavPath();
  }

  @override
  Future<void> onNavPathChanged(String path) async {
    await traceAs("onNavPathChanged", (trace) async {
      final parts = path.split("/");
      await _store.setActiveTab(
          trace, StageTab.values.byName(parts[0].toLowerCase()));
      if (parts.length > 1) {
        await _store.setTabPayload(trace, parts[1]);
      } else {
        await _store.setTabPayload(trace, null);
      }
      trace.addAttribute("navPath", path);
    });
  }

  @override
  Future<void> onForeground(bool isForeground) async {
    await traceAs("onForeground", (trace) async {
      await _store.setForeground(trace, isForeground);
    });
  }

  @override
  Future<void> onModalTriggered(String modal) async {
    await traceAs("onModalTriggered", (trace) async {
      await _store.showModalNow(
          trace, StageModal.values.byName(modal.toLowerCase()));
    });
  }

  @override
  Future<void> onModalDismissedByUser() async {
    await traceAs("onModalDismissedByUser", (trace) async {
      await _store.dismissModal(trace, byPlatform: false);
    });
  }

  @override
  Future<void> onModalDismissedByPlatform() async {
    await traceAs("onModalDismissedByPlatform", (trace) async {
      await _store.dismissModal(trace, byPlatform: true);
    });
  }

  // Push modal changes to the channel
  _onModal() {
    autorun((_) async {
      await traceAs("onModal", (trace) async {
        await _ops.doShowModal(_store.modal.name);
        trace.addAttribute("modal", _store.modal);
      });
    });
  }

  _onNavPath() {
    reactionOnStore((_) => [_store.activeTab, _store.tabPayload],
        (List<dynamic> path) async {
      await traceAs("onNavPath", (trace) async {
        final tab = path[0] as StageTab;
        final payload = path[1] as String?;
        final parsed = "${tab.name}${payload != null ? "/$payload" : ""}";
        await _ops.doNavPathChanged(parsed);
        trace.addAttribute("path", parsed);
      });
    });
  }
}

Future<void> init() async {
  di.registerSingleton<StageOps>(StageOps());
  di.registerSingleton<StageStore>(StageStore());
  StageBinder();
}
