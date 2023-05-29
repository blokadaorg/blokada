import 'package:mobx/mobx.dart';

import '../event.dart';
import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.pg.dart';

part 'stage.g.dart';

enum StageTab { root, home, activity, advanced, settings }

class StageRoute {
  final String path;
  final StageTab tab;
  final String? payload;

  StageRoute({
    required this.path,
    required this.tab,
    this.payload,
  });

  StageRoute.root() : this(path: "/", tab: StageTab.root, payload: null);

  StageRoute.fromPath(String path)
      : this(
            path: path.toLowerCase(),
            tab: _pathToTab(path),
            payload: _pathToPayload(path));

  StageRoute.forTab(StageTab tab)
      : this(path: tab.name, tab: tab, payload: null);

  bool isTop(StageTab tab) {
    return this.tab == tab && payload == null;
  }

  static StageTab _pathToTab(String path) {
    final parts = path.split("/");
    try {
      return StageTab.values.byName(parts[0].toLowerCase());
    } catch (e) {
      return StageTab.home;
    }
  }

  static String? _pathToPayload(String path) {
    final parts = path.split("/");
    if (parts.length > 1) {
      return parts[1];
    } else {
      return null;
    }
  }
}

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
  updateComplete,
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

abstract class StageStoreBase with Store, Traceable, Dependable {
  late final _ops = dep<StageOps>();
  late final _event = dep<EventBus>();

  final List<StageModal> _modalQueue = [];

  @observable
  bool isForeground = false;

  @observable
  StageRoute route = StageRoute.root();

  @observable
  StageModal modal = StageModal.none;

  DateTime? _lastDismissTimestamp;

  // Queue up events that happened before the app was initialized, for later.
  @observable
  bool isReady = false;

  @observable
  List<StageWaitingEvent> _waitingEvents = [];

  StageStoreBase() {
    reactionOnStore((_) => modal, (modal) async {
      await _ops.doShowModal(modal.name);
    });

    reactionOnStore((_) => route, (route) async {
      await _ops.doNavPathChanged(route.path);
    });
  }

  @override
  attach() {
    depend<StageOps>(StageOps());
    depend<StageStore>(this as StageStore);
  }

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
        trace.addAttribute("foreground", isForeground);
        await _event.onEvent(trace, CommonEvent.stageForegroundChanged);
      }
    });
  }

  @action
  Future<void> setRoute(Trace parentTrace, String path) async {
    return await traceWith(parentTrace, "setRoute", (trace) async {
      if (path != route.path) {
        if (!isReady) {
          _waitingEvents.add(StageWaitingEvent("setRoute", path));
          trace.addEvent("event queued");
          return;
        }
        route = StageRoute.fromPath(path);
        trace.addAttribute("route", route.path);
        await _event.onEvent(trace, CommonEvent.stageRouteChanged);
      }
    });
  }

  @action
  Future<void> showModalNow(Trace parentTrace, StageModal modal) async {
    return await traceWith(parentTrace, "showModalNow", (trace) async {
      if (this.modal != modal) {
        _lastDismissTimestamp = DateTime.now();
        _modalQueue.clear();
        await _updateModal(trace, modal);
      }
    });
  }

  @action
  Future<void> queueModal(Trace parentTrace, StageModal modal) async {
    return await traceWith(parentTrace, "queueModal", (trace) async {
      _modalQueue.add(modal);
      if (this.modal == StageModal.none) {
        _lastDismissTimestamp = DateTime.now();
        await _updateModal(trace, _modalQueue.removeAt(0));
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
          _lastDismissTimestamp = DateTime.now();
          await _updateModal(trace, StageModal.none);
        }
      }

      if (_modalQueue.isNotEmpty) {
        await _updateModal(trace, _modalQueue.removeAt(0));
      }
    });
  }

  @action
  Future<void> setReady(Trace parentTrace, bool isReady) async {
    return await traceWith(parentTrace, "setStageReady", (trace) async {
      trace.addAttribute("ready", isReady);
      if (this.isReady == isReady) {
        return;
      }
      this.isReady = isReady;
      if (isReady && _waitingEvents.isNotEmpty) {
        final events = _waitingEvents.toList();
        _waitingEvents = [];
        // Process queued events when the app is ready
        trace.addAttribute("queueProcessed", events);
        for (final event in events) {
          switch (event.name) {
            case "setForeground":
              await setForeground(trace, event.payload as bool);
              break;
            case "setRoute":
              await setRoute(trace, event.payload);
              break;
          }
        }
      }
    });
  }

  _updateModal(Trace trace, StageModal modal) async {
    this.modal = modal;
    await _event.onEvent(trace, CommonEvent.stageModalChanged);
  }
}
