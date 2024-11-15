import 'package:common/core/core.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/v6/widget/home/home_screen.dart';
import 'package:common/v6/widget/home/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

class Scaffolding extends StatefulWidget {
  const Scaffolding({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<Scaffolding> createState() => _ScaffoldingState();
}

const pathHomeStats = "home/stats";

class _ScaffoldingState extends State<Scaffolding> with Logging {
  final _stage = dep<StageStore>();

  final _pageCtrl = PageController(initialPage: 0);
  final _duration = const Duration(milliseconds: 800);
  final _curve = Curves.easeInOut;

  var _path = "home";
  String? _knownRoute;
  StageModal? _modal;

  @override
  void initState() {
    super.initState();

    _pageCtrl.addListener(() {
      if (_pageCtrl.page == 1 && _path != pathHomeStats) {
        _path = pathHomeStats;

        log(Markers.userTap).trace("scrolledToStats", (m) async {
          await _stage.setRoute(_path, m);
        });
      } else if (_pageCtrl.page == 0 && _path != "home") {
        _path = "home";

        log(Markers.userTap).trace("scrolledToHome", (m) async {
          await _stage.setRoute(_path, m);
        });
      }
    });

    autorun((_) {
      final path = _stage.route.route.path;
      if (path == _path) return;
      _path = path;

      setState(() {
        if (path == pathHomeStats) {
          _animateToPage(1);
        } else if (_stage.route.isTab(StageTab.home) &&
            _stage.route.isMainRoute()) {
          _animateToPage(0);
        }
      });
    });

    autorun((_) {
      final modal = _stage.route.modal;
      setState(() {
        _modal = modal;
      });
      // } else if (path == StageKnownRoute.homeOverlayLock.path) {
      //   _knownRoute = StageKnownRoute.homeOverlayLock;
      //   _animateToPage(0);
      // } else if (path == StageKnownRoute.homeOverlayRate.path) {
      // _knownRoute = StageKnownRoute.homeOverlayRate;
      // _animateToPage(0);
      // } else if (path == StageKnownRoute.homeOverlayCrash.path) {
      // _knownRoute = StageKnownRoute.homeOverlayCrash;
      // _animateToPage(0);
      // } else if (path == StageKnownRoute.homeCloseOverlay.path) {
      // _knownRoute = null;
      // _animateToPage(0);
      // }
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
            children: _getPages(),
          ),
        ],
      ),
    );
  }

  _getPages() {
    return <Widget>[
      // const Coolbg(),
      HomeScreen(),
      StatsScreen(
          key: UniqueKey(), autoRefresh: true, controller: ScrollController()),
    ];
  }
}
