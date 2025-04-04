import 'dart:async';

import 'package:common/common/module/link/link.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';

import 'channel.act.dart';
import 'channel.pg.dart';

part 'stage.g.dart';

final routeChanged = EmitterEvent<StageRouteState>("routeChanged");
final willEnterBackground = EmitterEvent("willEnterBackground");

enum StageTab { background, home, activity, advanced, settings }

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
  final StageModal? prevModal;
  final Map<StageTab, StageRoute> _tabStates;

  StageRouteState(
    this.route,
    this._prevRoute,
    this.modal,
    this.prevModal,
    this._tabStates,
  );

  StageRouteState.init()
      : this(_background, StageRoute.forTab(StageTab.home), null, null, {});

  StageRouteState newBg() => (route == _background)
      ? this
      : StageRouteState(_background, route, modal, modal, _tabStates);

  StageRouteState newFg({StageModal? m}) => StageRouteState(
      _prevRoute, _background, m ?? modal, m ?? modal, _tabStates);

  StageRouteState newRoute(StageRoute route) {
    // Restore the state for this tab if exists
    if (route.tab != this.route.tab && route.payload == null && modal == null) {
      if (_tabStates.containsKey(route.tab)) {
        final r = _tabStates[route.tab]!;

        // Home is special because of the stats sub-screen, we do not want it
        // to reset the deep navigation on the second tap of the Home tab.
        if (route.tab != StageTab.home) _tabStates.remove(route.tab);

        return StageRouteState(r, this.route, modal, modal, _tabStates);
      }
    }
    _tabStates[route.tab] = route;
    return StageRouteState(route, this.route, modal, modal, _tabStates);
  }

  StageRouteState newModal(StageModal? modal) =>
      StageRouteState(route, route, modal, this.modal, _tabStates);

  StageRouteState newTab(StageTab tab) =>
      StageRouteState(StageRoute.forTab(tab), route, modal, modal, _tabStates);

  bool isForeground() => route != _background;
  bool isTab(StageTab tab) => route.tab == tab;
  bool isModal(StageModal modal) => this.modal == modal;
  bool isMainRoute() => route.payload == null && modal == null;
  bool isSection(String section) => route.payload?.startsWith(section) ?? false;

  bool isBecameForeground() => isForeground() && _prevRoute == _background;
  bool isBecameTab(StageTab tab) {
    if (route.tab != tab) return false;
    if (route.tab != _prevRoute.tab) return true;
    return false;
  }

  bool isBecameModal(StageModal modal) {
    if (this.modal != modal) return false;
    if (this.modal != prevModal) return true;
    return false;
  }

  bool wasModal(StageModal modal) => prevModal == modal;
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
    with Store, Logging, Actor, ValueEmitter<StageRouteState>, Emitter {
  late final _ops = Core.get<StageOps>();
  late final _scheduler = Core.get<Scheduler>();
  late final _links = Core.get<LinkActor>();

  @observable
  StageRouteState route = StageRouteState.init();

  // Obsolete
  @observable
  bool isReady = true;

  bool _isForeground = false;
  Completer? _foregroundCompleter;

  StageModal? _modalToShow;
  String? _pathToShow;
  bool _showNavbar = true;

  StageModal? _waitingOnModal;
  Completer? _modalCompleter;
  Completer? _dismissModalCompleter;

  StageStoreBase() {
    willAcceptOnValue(routeChanged);
    willAcceptOn([willEnterBackground]);
  }

  @override
  onRegister() {
    Core.register<StageOps>(getOps());
    Core.register<StageStore>(this as StageStore);
  }

  @action
  Future<void> setForeground(Marker m) async {
    return await log(m).trace("setForeground", (m) async {
      if (_foregroundCompleter != null) {
        log(m).i("waiting for previous fg/bg to finish");
        await _foregroundCompleter?.future;
      }

      _foregroundCompleter = Completer();

      _isForeground = true;
      if (isReady) await _processWaiting(m);

      _foregroundCompleter?.complete();
      _foregroundCompleter = null;
    });
  }

  @action
  Future<void> setBackground(Marker m) async {
    return await log(m).trace("setBackground", (m) async {
      if (_foregroundCompleter != null) {
        log(m).i("waiting for previous fg/bg to finish");
        await _foregroundCompleter?.future;
      }

      _foregroundCompleter = Completer();

      if (route.isForeground()) {
        await emit(willEnterBackground, route, m);
        route = route.newBg();
        _isForeground = false;
        await emitValue(routeChanged, route, m);

        await _scheduler.eventTriggered(m, Event.appForeground, value: "0");
      }

      _foregroundCompleter?.complete();
      _foregroundCompleter = null;
    });
  }

  @action
  Future<void> setRoute(String path, Marker m) async {
    return await log(m).trace("setRoute", (m) async {
      if (path != route.route.path) {
        if (!isReady || !_isForeground) {
          _pathToShow = path;
          log(m).w("not ready, route saved: $path");
          return;
        }

        final newRoute =
            route.newModal(null).newRoute(StageRoute.fromPath(path));

        log(m).log(msg: "setRoute", attr: {
          "route": newRoute.route.path,
          "prev": newRoute._prevRoute.path,
          "isBecameForeground": newRoute.isBecameForeground(),
        });

        // Navigating between routes (tabs) will close modal, but not coming fg.
        if (!newRoute.isBecameForeground()) {
          if (route.modal != null) {
            log(m).i("dismiss modal");
            await dismissModal(m);
            await sleepAsync(_afterDismissWait);
          }
        }

        if (!newRoute.isMainRoute()) {
          log(m).log(attr: {
            "tab": newRoute.route.tab,
            "payload": newRoute.route.payload,
          });
        }
        route = newRoute;
        await emitValue(routeChanged, newRoute, m);
      }
    });
  }

  late final ctrl = Core.get<TopBarController>();

  @action
  Future<void> back() async {
    if (!ctrl.goBackFromPlatform()) {
      await _ops.doHomeReached();
    }
  }

  @action
  Future<void> setReady(bool isReady, Marker m) async {
    // TODO: obsolete, unused anymore
  }

  @action
  Future<void> setShowNavbar(bool show, Marker m) async {
    return await log(m).trace("setShowNavbar", (m) async {
      if (_showNavbar == show) return;
      _showNavbar = show;
      log(m).log(attr: {"show": show});
      await _actOnModal(route.modal, m);
    });
  }

  _processWaiting(Marker m) async {
    if (!route.isForeground()) {
      route = route.newFg();

      if (!route.isForeground()) {
        // A dirty hack since I can't figure out why its bg sometimes
        route = StageRouteState.init().newFg(m: route.modal);
        log(m).w("routeFgHack");
      }

      log(m).i("foreground emitting");
      await emitValue(routeChanged, route, m);

      // TODO: this needs to be removed
      await _scheduler.eventTriggered(m, Event.appForeground, value: "1");
    }

    final path = _pathToShow;
    if (path != null) {
      _pathToShow = null;
      await setRoute(path, m);
      log(m).i("path emitted");
    }

    final modal = _modalToShow;
    if (modal != null) {
      _modalToShow = null;
      await showModal(modal, m);
      log(m).i("modal emitted");
    }
  }

  @action
  Future<void> showModal(StageModal modal, Marker m) async {
    return await log(m).trace("showModal", (m) async {
      log(m).i("modal: $modal");
      if (route.modal != modal) {
        if (!isReady || (!_isForeground && !_modalIsException(modal))) {
          _modalToShow = modal;
          log(m).i("not ready, modal saved: $modal");
          return;
        }

        if (_modalCompleter != null) {
          log(m).i("waiting for previous modal request to finish");
          await _modalCompleter?.future;
        }

        if (route.modal != null) {
          log(m).i("dismiss previous modal");
          await dismissModal(m);
          await sleepAsync(_afterDismissWait);
        }

        _modalCompleter = Completer();
        _waitingOnModal = modal;
        // await setReady(false);
        await _ops.doShowModal(modal);
        await _modalCompleter?.future;
        // await setReady(true);
        _modalCompleter = null;
        _waitingOnModal = null;

        await _updateModal(modal, m);
      }
    });
  }

  @action
  Future<void> modalShown(StageModal modal, Marker m) async {
    return await log(m).trace("modalShown", (m) async {
      if (_waitingOnModal == modal) {
        _modalCompleter?.complete();
      } else {
        log(m).i("modalShown: wrong modal: $modal, waiting: $_waitingOnModal");
      }
    });
  }

  @action
  Future<void> dismissModal(Marker m) async {
    return await log(m).trace("dismissModal", (m) async {
      if (route.modal != null) {
        if (_dismissModalCompleter != null) {
          return;
        }

        _dismissModalCompleter = Completer();
        // await setReady(false);
        await _ops.doDismissModal();
        await _dismissModalCompleter?.future;
        // await setReady(true);
        _dismissModalCompleter = null;

        await _updateModal(null, m);
      } else {
        await _ops.doDismissModal();
      }
    });
  }

  @action
  Future<void> modalDismissed(Marker m) async {
    return await log(m).trace("modalDismissed", (m) async {
      if (_dismissModalCompleter == null && route.modal != null) {
        await _updateModal(null, m);
      } else {
        _dismissModalCompleter?.complete();
      }
    });
  }

  _updateModal(StageModal? modal, Marker m) async {
    route = route.newModal(modal);
    await emitValue(routeChanged, route, m);
    await _actOnModal(modal, m);
  }

  final noNavbarModals = [
    StageModal.lock,
    StageModal.rate,
    StageModal.onboarding,
  ];

  _actOnModal(StageModal? modal, Marker m) async {
    var show = !noNavbarModals.contains(modal);
    if (!_showNavbar) show = false;
    if (Core.act.isFamily) show = false;
    log(m).log(attr: {"show": show});
  }

  @action
  Future<void> openLink(LinkId link, Marker m) async {
    return await log(m).trace("openLink", (m) async {
      final url = _links.links[link];
      if (url != null) {
        await _ops.doOpenLink(url);
      } else {
        throw Exception("Link not found: $link");
      }
    });
  }

  @action
  Future<void> openUrl(String url, Marker m) async {
    return await log(m).trace("openUrl", (m) async {
      await _ops.doOpenLink(url);
    });
  }

  bool _modalIsException(StageModal modal) {
    // Only on android we can invoke sheets before Foreground
    if (Core.act.platform != PlatformType.android) return false;
    return modal == StageModal.onboarding;
  }
}
