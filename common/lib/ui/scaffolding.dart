import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../stage/channel.pg.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/trace.dart';
import 'coolbg.dart';
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

  var showBottom = false;
  bool isLocked = false;
  bool isRate = false;

  var _path = "home";

  @override
  void initState() {
    super.initState();

    _pageCtrl.addListener(() {
      if (_pageCtrl.page == 1) {
        _path = StageKnownRoute.homeStats.path;

        traceAs("fromWidget", (trace) async {
          await _stage.setRoute(trace, _path);
        });
      } else if (_pageCtrl.page == 0) {
        _path = "home";

        traceAs("fromWidget", (trace) async {
          await _stage.setRoute(trace, _path);
        });
      }
    });

    autorun((_) {
      final path = _stage.route.route.path;
      if (path == _path) return;
      _path = path;

      setState(() {
        if (path == StageKnownRoute.homeLock.path) {
          isLocked = true;
          _pageCtrl.animateToPage(0, duration: _duration, curve: _curve);
        } else if (path == StageKnownRoute.homeUnlock.path) {
          isLocked = false;
        } else if (path == StageKnownRoute.homeRate.path) {
          isRate = true;
          _pageCtrl.animateToPage(0, duration: _duration, curve: _curve);
        } else if (path == StageKnownRoute.homeCloseRate.path) {
          isRate = false;
          _pageCtrl.animateToPage(0, duration: _duration, curve: _curve);
        } else if (path == StageKnownRoute.homeStats.path) {
          _pageCtrl.animateToPage(1, duration: _duration, curve: _curve);
        } else if (_stage.route.isTab(StageTab.home) &&
            _stage.route.isMainRoute()) {
          _pageCtrl.animateToPage(0, duration: _duration, curve: _curve);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            physics: isLocked ? const NeverScrollableScrollPhysics() : null,
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
          if (isLocked) const LockScreen() else if (isRate) const RateScreen()
        ],
      ),
    );
  }
}
