import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'coolbg.dart';
import 'crash/crash_screen.dart';
import 'home/home_screen.dart';
import 'lock/lock_screen.dart';
import 'rate/rate_screen.dart';
import 'stats/stats_screen.dart';

class Scaffolding extends StatefulWidget {
  const Scaffolding({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<Scaffolding> createState() => _ScaffoldingState();
}

class _ScaffoldingState extends State<Scaffolding> with Traceable, TraceOrigin {
  final _stage = dep<StageStore>();

  final _pageCtrl = PageController(initialPage: 0);
  final _duration = const Duration(milliseconds: 800);
  final _curve = Curves.easeInOut;

  var _path = "home";
  StageKnownRoute? _knownRoute;

  @override
  void initState() {
    super.initState();

    _pageCtrl.addListener(() {
      if (_pageCtrl.page == 1 && _path != StageKnownRoute.homeStats.path) {
        _path = StageKnownRoute.homeStats.path;

        traceAs("scrolledToStats", (trace) async {
          await _stage.setRoute(trace, _path);
        });
      } else if (_pageCtrl.page == 0 && _path != "home") {
        _path = "home";

        traceAs("scrolledToHome", (trace) async {
          await _stage.setRoute(trace, _path);
        });
      }
    });

    autorun((_) {
      final path = _stage.route.route.path;
      if (path == _path) return;
      _path = path;

      setState(() {
        if (path == StageKnownRoute.homeStats.path) {
          _animateToPage(1);
        } else if (_stage.route.isTab(StageTab.home) &&
            _stage.route.isMainRoute()) {
          _animateToPage(0);
        } else if (path == StageKnownRoute.homeOverlayLock.path) {
          _knownRoute = StageKnownRoute.homeOverlayLock;
          _animateToPage(0);
        } else if (path == StageKnownRoute.homeOverlayRate.path) {
          _knownRoute = StageKnownRoute.homeOverlayRate;
          _animateToPage(0);
        } else if (path == StageKnownRoute.homeOverlayCrash.path) {
          _knownRoute = StageKnownRoute.homeOverlayCrash;
          _animateToPage(0);
        } else if (path == StageKnownRoute.homeCloseOverlay.path) {
          _knownRoute = null;
          _animateToPage(0);
        }
      });
    });
  }

  _animateToPage(int page) {
    _pageCtrl.animateToPage(page, duration: _duration, curve: _curve);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            physics: _knownRoute != null
                ? const NeverScrollableScrollPhysics()
                : null,
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            children: <Widget>[
              // const Coolbg(),
              HomeScreen(),
              StatsScreen(
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
        ],
      ),
    );
  }
}
