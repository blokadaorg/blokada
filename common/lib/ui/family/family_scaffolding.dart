import 'package:common/ui/background.dart';
import 'package:common/ui/family/homefamily/homefamily_screen.dart';
import 'package:common/ui/family/familystats_screen.dart';
import 'package:common/ui/theme.dart';
import 'package:common/util/config.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../lock/lock.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';

class FamilyScaffolding extends StatefulWidget {
  const FamilyScaffolding({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<FamilyScaffolding> createState() => _FamilyScaffoldingState();
}

const pathHomeStats = "home/stats";

class _FamilyScaffoldingState extends State<FamilyScaffolding>
    with Traceable, TraceOrigin {
  final _stage = dep<StageStore>();
  final _lock = dep<LockStore>();

  final _verticalPageCtrl = PageController(initialPage: 1);
  final _horizontalPageCtrl = PageController(initialPage: 0);
  final _duration = const Duration(milliseconds: 400);
  final _curve = Curves.easeInOut;

  final _verticalPageViewKey = GlobalKey();
  final _horizontalPageViewKey = GlobalKey();

  var _path = "home";
  String? _knownRoute;
  StageModal? _modal;

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
      } else if (_horizontalPageCtrl.page == 1 && _path != pathHomeStats) {
        _path = pathHomeStats;

        traceAs("scrolledToStats", (trace) async {
          await _stage.setRoute(trace, _path);
        });
      }
    });

    autorun((_) {
      final path = _stage.route.route.path;
      if (path == _path) return;

      setState(() {
        _path = path;

        if (path == pathHomeStats) {
          //_animateToPage(1);
          _animateToPageHorizontal(1);
        } else if (_stage.route.isTab(StageTab.home) &&
            (_stage.route.isMainRoute())) {
          //_animateToPage(1);
          _animateToPageHorizontal(0);
        }
      });
    });

    autorun((_) {
      setState(() {
        _locked = _lock.isLocked;
      });
    });

    autorun((_) {
      final modal = _stage.route.modal;
      setState(() {
        _modal = modal;
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
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff4ae5f6),
              Color(0xff3c8cff),
              Color(0xff3c8cff),
            ],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.transparent,
                Color(0xffe450cd),
                Color(0xffe450cd),
              ],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  theme.bgColorHome1.withOpacity(0.4),
                  theme.bgColorHome2,
                  theme.bgColorHome2,
                  theme.bgColorHome2,
                ],
              ),
            ),
            child: Stack(
              children: [
                PageView(
                  physics: _path == pathHomeStats
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  controller: _horizontalPageCtrl,
                  scrollDirection: Axis.horizontal,
                  children: [
                    HomeFamilyScreen(),
                    FamilyStatsScreen(
                      key: UniqueKey(),
                      onBack: () {
                        _animateToPageHorizontal(0);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
