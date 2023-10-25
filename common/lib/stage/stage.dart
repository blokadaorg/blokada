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
      case StageKnownRoute.homeOverlayFamilyOnboard:
        return "home/familyonboard";
      case StageKnownRoute.homeOverlayFamilyDevices:
        return "home/familydevices";
    }
  }
}

final _background =
    StageRoute(path: "", tab: StageTab.background, payload: null);

const _afterDismissWait = Duration(milliseconds: 1000);

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

  bool _isForeground = false;
  StageModal? _modalToShow;
  String? _pathToShow;

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
      _isForeground = true;
      if (isReady) await _processWaiting(trace);
    });
  }

  @action
  Future<void> setBackground(Trace parentTrace) async {
    return await traceWith(parentTrace, "setBackground", (trace) async {
      _isForeground = false;
      if (isReady && route.isForeground()) {
        route = route.newBg();
        await emitValue(routeChanged, trace, route);
      }
    });
  }

  @action
  Future<void> setRoute(Trace parentTrace, String path) async {
    return await traceWith(parentTrace, "setRoute", (trace) async {
      if (path != route.route.path) {
        if (!isReady || !_isForeground) {
          _pathToShow = path;
          trace.addEvent("not ready, route saved: $path");
          return;
        }

        final newRoute =
            route.newModal(null).newRoute(StageRoute.fromPath(path));
        trace.addEvent("route: ${newRoute.route.path}");
        trace.addEvent("previous: ${newRoute._prevRoute.path}");
        trace.addEvent("isBecameForeground: ${newRoute.isBecameForeground()}");

        // Navigating between routes (tabs) will close modal, but not coming fg.
        if (!newRoute.isBecameForeground()) {
          if (route.modal != null) {
            trace.addEvent("dismiss modal");
            await dismissModal(trace);
            await sleepAsync(_afterDismissWait);
          }
        }

        if (!newRoute.isMainRoute()) {
          trace.addEvent("modal: ${newRoute.modal}");
          trace.addEvent("payload: ${newRoute.route.payload}");
        }
        route = newRoute;
        await _actOnRoute(trace, newRoute.route);
        await emitValue(routeChanged, trace, newRoute);
      }
    });
  }

  @action
  Future<void> setReady(Trace parentTrace, bool isReady) async {
    return await traceWith(parentTrace, "setStageReady", (trace) async {
      if (this.isReady == isReady) return;
      this.isReady = isReady;
      if (isReady && _isForeground) await _processWaiting(trace);
    });
  }

  _processWaiting(Trace trace) async {
    if (!route.isForeground()) {
      route = route.newFg();
      await emitValue(routeChanged, trace, route);
      trace.addEvent("foreground emitted");
    }

<<<<<<< HEAD
    final path = _pathToShow;
    if (path != null) {
      _pathToShow = null;
      await setRoute(trace, path);
      trace.addEvent("path emitted");
    }
=======
    return await traceWith(parentTrace, "setLocked", (trace) async {
      this.isLocked = isLocked;
      trace.addAttribute("isLocked", isLocked);
      await _ops.doShowNavbar(!isLocked);
      await _processQueue(trace);
    });
  }
>>>>>>> 30c1e06 (hide nav bar when locked)

    final modal = _modalToShow;
    if (modal != null) {
      _modalToShow = null;
      await showModal(trace, modal);
      trace.addEvent("modal emitted");
    }
  }

  @action
  Future<void> showModal(Trace parentTrace, StageModal modal) async {
    return await traceWith(parentTrace, "showModal", (trace) async {
      trace.addEvent("modal: $modal");
      if (route.modal != modal) {
        if (!isReady || !_isForeground) {
          _modalToShow = modal;
          trace.addEvent("not ready, modal saved: $modal");
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
    } else if (route.path == StageKnownRoute.homeOverlayFamilyOnboard.path) {
      await _ops.doShowNavbar(false);
    } else if (route.path == StageKnownRoute.homeCloseOverlay.path &&
        !isLocked) {
      await _ops.doShowNavbar(true);
    }
  }
}
