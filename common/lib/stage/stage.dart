import 'dart:async';
import 'dart:io';

import 'package:mobx/mobx.dart';

import '../util/async.dart';
import '../util/di.dart';
import '../util/emitter.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'stage.g.dart';

final routeChanged = EmitterEvent<StageRouteState>();

enum StageTab { background, home, activity, advanced, settings }

extension StageKnownRouteExt on StageKnownRoute {
  String get path {
    switch (this) {
      case StageKnownRoute.homeStats:
        return "home/stats";
      case StageKnownRoute.homeCloseOverlay:
        return "home/close";
      case StageKnownRoute.homeOverlayLock:
        return "home/lock";
      case StageKnownRoute.homeOverlayRate:
        return "home/rate";
      case StageKnownRoute.homeOverlayCrash:
        return "home/crash";
    }
  }
}

final _background =
    StageRoute(path: "", tab: StageTab.background, payload: null);

const _afterDismissWait = Duration(milliseconds: 500);

class StageRoute {
  final String path;
  final StageTab tab;
  final String? payload;

  StageRoute({
    required this.path,
    required this.tab,
    this.payload,
  });

  StageRoute.fromPath(String path)
      : this(path: path, tab: _pathToTab(path), payload: _pathToPayload(path));

  StageRoute.forTab(StageTab tab)
      : this(path: tab.name, tab: tab, payload: null);

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

class StageRouteState {
  final StageRoute route;
  final StageRoute _prevRoute;
  final StageModal? modal;
  final StageModal? _prevModal;
  final Map<StageTab, StageRoute> _tabStates;

  StageRouteState(
    this.route,
    this._prevRoute,
    this.modal,
    this._prevModal,
    this._tabStates,
  );

  StageRouteState.init()
      : this(_background, StageRoute.forTab(StageTab.home), null, null, {});

  newBg() => StageRouteState(_background, route, modal, modal, _tabStates);

  newFg() => StageRouteState(_prevRoute, route, modal, modal, _tabStates);

  newRoute(StageRoute route) {
    // Restore the state for this tab if exists
    if (route.tab != this.route.tab && route.payload == null && modal == null) {
      if (_tabStates.containsKey(route.tab)) {
        final r = _tabStates[route.tab]!;
        _tabStates.remove(route.tab);
        return StageRouteState(r, this.route, modal, modal, _tabStates);
      }
    }
    _tabStates[route.tab] = route;
    return StageRouteState(route, this.route, modal, modal, _tabStates);
  }

  newModal(StageModal? modal) =>
      StageRouteState(route, route, modal, this.modal, _tabStates);

  newTab(StageTab tab) =>
      StageRouteState(StageRoute.forTab(tab), route, modal, modal, _tabStates);

  bool isForeground() => route != _background;
  bool isTab(StageTab tab) => route.tab == tab;
  bool isModal(StageModal modal) => this.modal == modal;
  bool isMainRoute() => route.payload == null && modal == null;
  bool isKnown(StageKnownRoute to) =>
      ("${route.tab.name}/${route.payload ?? ""}") == to.path;

  bool isBecameForeground() => isForeground() && _prevRoute == _background;
  bool isBecameTab(StageTab tab) {
    if (route.tab != tab) return false;
    if (route.tab != _prevRoute.tab) return true;
    return false;
  }

  bool isBecameModal(StageModal modal) {
    if (this.modal != modal) return false;
    if (this.modal != _prevModal) return true;
    return false;
  }
}

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

abstract class StageStoreBase
    with Store, Traceable, Dependable, ValueEmitter<StageRouteState> {
  late final _ops = dep<StageOps>();

  @observable
  StageRouteState route = StageRouteState.init();

  // Queue up events that happened before the app was initialized, for later.
  @observable
  bool isReady = false;

  @observable
  bool isLocked = false;

  @observable
  List<String> _waitingEvents = [];

  StageModal? _waitingOnModal;
  Completer? _modalCompleter;
  Completer? _dismissModalCompleter;

  StageStoreBase() {
    willAcceptOnValue(routeChanged);

    reactionOnStore((_) => route, (route) async {
      await _ops.doRouteChanged(route.route.path);
    });
  }

  @override
  attach(Act act) {
    depend<StageOps>(getOps(act));
    depend<StageStore>(this as StageStore);
  }

  @action
  Future<void> setForeground(Trace parentTrace) async {
    return await traceWith(parentTrace, "setForeground", (trace) async {
      if (!route.isForeground()) {
        if (!isReady) {
          await setRoute(trace, route.newFg().route.path);
        } else {
          route = route.newFg();
          await emitValue(routeChanged, trace, route);
        }
      }
    });
  }

  @action
  Future<void> setBackground(Trace parentTrace) async {
    return await traceWith(parentTrace, "setBackground", (trace) async {
      if (route.isForeground()) {
        route = route.newBg();
        await emitValue(routeChanged, trace, route);
      }
    });
  }

  @action
  Future<void> setRoute(Trace parentTrace, String path) async {
    return await traceWith(parentTrace, "setRoute", (trace) async {
      if (path != route.route.path) {
        if (!isReady ||
            isLocked && path != StageKnownRoute.homeOverlayLock.path) {
          _waitingEvents.add(path);
          trace.addEvent("event queued: $path");
          return;
        }

        route = route.newRoute(StageRoute.fromPath(path));
        trace.addEvent("route: ${route.route.path}");
        trace.addEvent("previous: ${route._prevRoute.path}");
        trace.addEvent("isBecameForeground: ${route.isBecameForeground()}");

        // Navigating between routes (tabs) will close modal, but not coming fg.
        if (!route.isBecameForeground()) {
          if (route.modal != null) {
            trace.addEvent("dismiss modal");
            await dismissModal(trace);
            await sleepAsync(_afterDismissWait);
          }
        }

        if (!route.isMainRoute()) {
          trace.addEvent("modal: ${route.modal}");
          trace.addEvent("payload: ${route.route.payload}");
        }
        await _actOnRoute(trace, route.route);
        await emitValue(routeChanged, trace, route);
      }
    });
  }

  @action
  Future<void> setReady(Trace parentTrace, bool isReady) async {
    return await traceWith(parentTrace, "setStageReady", (trace) async {
      if (this.isReady == isReady) return;
      this.isReady = isReady;
      await _processQueue(trace);
    });
  }

  @action
  Future<void> setLocked(Trace parentTrace, bool isLocked) async {
    if (this.isLocked == isLocked) return;

    return await traceWith(parentTrace, "setLocked", (trace) async {
      this.isLocked = isLocked;
      trace.addAttribute("isLocked", isLocked);
      await _processQueue(trace);
    });
  }

  _processQueue(Trace trace) async {
    if (isReady && !isLocked && _waitingEvents.isNotEmpty) {
      final events = _waitingEvents.toList();
      _waitingEvents = [];
      // Process queued events when the app is ready
      trace.addAttribute("queueProcessed", events);
      for (final event in events) {
        await setRoute(trace, event);
      }
    }
  }

  @action
  Future<void> showModal(Trace parentTrace, StageModal modal) async {
    return await traceWith(parentTrace, "showModal", (trace) async {
      trace.addEvent("modal: $modal");
      if (route.modal != modal) {
        if (Platform.isAndroid && !route.isForeground()) {
          trace.addEvent("ignoring modal request, app in background");
          return;
        }

        if (_modalCompleter != null) {
          trace.addEvent("waiting for previous modal request to finish");
          await _modalCompleter?.future;
        }

        if (route.modal != null) {
          trace.addEvent("dismiss previous modal");
          await dismissModal(trace);
          await sleepAsync(_afterDismissWait);
        }

        _modalCompleter = Completer();
        _waitingOnModal = modal;
        await setReady(trace, false);
        await _ops.doShowModal(modal);
        await _modalCompleter?.future;
        await setReady(trace, true);
        _modalCompleter = null;
        _waitingOnModal = null;

        await _updateModal(trace, modal);
      }
    });
  }

  @action
  Future<void> modalShown(Trace parentTrace, StageModal modal) async {
    return await traceWith(parentTrace, "modalShown", (trace) async {
      if (_waitingOnModal == modal) {
        _modalCompleter?.complete();
      } else {
        trace.addEvent("sheetShown ignored, wrong modal: $modal");
      }
    });
  }

  @action
  Future<void> dismissModal(Trace parentTrace) async {
    return await traceWith(parentTrace, "dismissModal", (trace) async {
      if (route.modal != null) {
        if (_dismissModalCompleter != null) {
          return;
        }

        _dismissModalCompleter = Completer();
        await setReady(trace, false);
        await _ops.doDismissModal();
        await _dismissModalCompleter?.future;
        await setReady(trace, true);
        _dismissModalCompleter = null;

        await _updateModal(trace, null);
      } else {
        await _ops.doDismissModal();
      }
    });
  }

  @action
  Future<void> modalDismissed(Trace parentTrace) async {
    return await traceWith(parentTrace, "modalDismissed", (trace) async {
      if (_dismissModalCompleter == null && route.modal != null) {
        await _updateModal(trace, null);
      } else {
        _dismissModalCompleter?.complete();
      }
    });
  }

  @action
  Future<void> showNavbar(Trace parentTrace, bool show) async {
    return await traceWith(parentTrace, "showNavbar", (trace) async {
      await _ops.doShowNavbar(show);
    });
  }

  _updateModal(Trace trace, StageModal? modal) async {
    route = route.newModal(modal);
    await emitValue(routeChanged, trace, route);
  }

  _actOnRoute(Trace trace, StageRoute route) async {
    if (route.path == StageKnownRoute.homeOverlayLock.path) {
      await _ops.doShowNavbar(false);
    } else if (route.path == StageKnownRoute.homeOverlayRate.path) {
      await _ops.doShowNavbar(false);
    } else if (route.path == StageKnownRoute.homeOverlayCrash.path) {
      await _ops.doShowNavbar(false);
    } else if (route.path == StageKnownRoute.homeCloseOverlay.path) {
      await _ops.doShowNavbar(true);
    }
  }
}
