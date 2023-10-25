import 'package:common/ui/background.dart';
import 'package:common/ui/homefamily/homefamily_screen.dart';
import 'package:common/ui/stats/familystats_screen.dart';
import 'package:common/ui/theme.dart';
import 'package:common/util/config.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../lock/lock.dart';
import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'crash/crash_screen.dart';
import 'lock/lock_screen.dart';
import 'onboard/family_onboard_screen.dart';
import 'rate/rate_screen.dart';

class FamilyScaffolding extends StatefulWidget {
  const FamilyScaffolding({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<FamilyScaffolding> createState() => _FamilyScaffoldingState();
}

class _FamilyScaffoldingState extends State<FamilyScaffolding>
    with Traceable, TraceOrigin {
  final _stage = dep<StageStore>();
  final _lock = dep<LockStore>();

  final _verticalPageCtrl = PageController(initialPage: 1);
  final _horizontalPageCtrl = PageController(initialPage: 0);
  final _duration = const Duration(milliseconds: 800);
  final _curve = Curves.easeInOut;

  final _verticalPageViewKey = GlobalKey();
  final _horizontalPageViewKey = GlobalKey();

  var _path = "home";
  StageKnownRoute? _knownRoute;

  var _locked = true;

  @override
  void initState() {
    super.initState();

    _verticalPageCtrl.addListener(() {
      // if (_verticalPageCtrl.page == 0 &&
      //     _path != StageKnownRoute.homeOverlayFamilyDevices.path) {
      //   _path = StageKnownRoute.homeOverlayFamilyDevices.path;
      //
      //   traceAs("scrolledToFamilyDevices", (trace) async {
      //     await _stage.setRoute(trace, _path);
      //   });
      // } else if (_verticalPageCtrl.page == 1 && _path != "home") {
      //   _path = "home";
      //
      //   traceAs("scrolledToHome", (trace) async {
      //     await _stage.setRoute(trace, _path);
      //   });
      // }
    });

    _horizontalPageCtrl.addListener(() {
      if (_horizontalPageCtrl.page == 0 && _path != "home") {
        _path = "home";

        traceAs("scrolledToHome", (trace) async {
          await _stage.setRoute(trace, _path);
        });
      } else if (_horizontalPageCtrl.page == 1 &&
          _path != StageKnownRoute.homeStats.path) {
        _path = StageKnownRoute.homeStats.path;

        traceAs("scrolledToStats", (trace) async {
          await _stage.setRoute(trace, _path);
        });
      }
    });

    autorun((_) {
      final path = _stage.route.route.path;
      if (path == _path) return;
      _path = path;

      setState(() {
        // if (path == StageKnownRoute.homeStats.path) {
        //   _animateToPage(1);
        // } else if (_stage.route.isTab(StageTab.home) &&
        if (_stage.route.isTab(StageTab.home) && _stage.route.isMainRoute()) {
          //_animateToPage(1);
          _animateToPageHorizontal(0);
        } else if (path == StageKnownRoute.homeOverlayLock.path) {
          _knownRoute = StageKnownRoute.homeOverlayLock;
          _animateToPage(1);
        } else if (path == StageKnownRoute.homeOverlayRate.path) {
          _knownRoute = StageKnownRoute.homeOverlayRate;
          _animateToPage(1);
        } else if (path == StageKnownRoute.homeOverlayCrash.path) {
          _knownRoute = StageKnownRoute.homeOverlayCrash;
          _animateToPage(1);
        } else if (path == StageKnownRoute.homeOverlayFamilyOnboard.path) {
          _knownRoute = StageKnownRoute.homeOverlayFamilyOnboard;
          _animateToPage(1);
        } else if (path == StageKnownRoute.homeCloseOverlay.path) {
          _knownRoute = null;
          _animateToPage(1);
        } else if (path == StageKnownRoute.homeOverlayFamilyDevices.path) {
          _animateToPage(0);
        } else if (path == StageKnownRoute.homeStats.path) {
          _animateToPageHorizontal(1);
        }
      });
    });

    autorun((_) {
      setState(() {
        _locked = _lock.isLocked;
      });
    });
  }

  _animateToPage(int page) {
    _verticalPageCtrl.animateToPage(page, duration: _duration, curve: _curve);
  }

  _animateToPageHorizontal(int page) {
    _horizontalPageCtrl.animateToPage(page, duration: _duration, curve: _curve);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.bgColorHome3,
              theme.bgColorHome2,
              theme.bgColorHome1,
              theme.bgColor,
              theme.bgColor,
            ],
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    theme.bgColorHome1,
                    theme.bgColor,
                    theme.bgColor,
                  ],
                ),
              ),
            ),
            (cfg.debugBg) ? CoolBackground() : Container(),
            PageView(
              physics: _knownRoute != null || _locked
                  ? const NeverScrollableScrollPhysics()
                  : null,
              controller: _horizontalPageCtrl,
              scrollDirection: Axis.horizontal,
              children: [
                PageView(
                  physics: _knownRoute != null || _locked || true
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  controller: _verticalPageCtrl,
                  scrollDirection: Axis.vertical,
                  children: [
                    Container(),
                    HomeFamilyScreen(),
                  ],
                ),
                FamilyStatsScreen(
                    key: UniqueKey(),
                    autoRefresh: true,
                    controller: ScrollController()),
              ],
            ),
            if (_knownRoute == StageKnownRoute.homeOverlayLock)
              const LockScreen()
            else if (_knownRoute == StageKnownRoute.homeOverlayRate)
              const RateScreen()
            else if (_knownRoute == StageKnownRoute.homeOverlayCrash)
              const CrashScreen()
            else if (_knownRoute == StageKnownRoute.homeOverlayFamilyOnboard)
              const FamilyOnboardScreen()
          ],
        ),
      ),
    );
  }
}
