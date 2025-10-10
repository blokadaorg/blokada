import 'dart:ui';

import 'package:common/common/navigation.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/v6/widget/tab/tab_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TabWidget extends StatefulWidget {
  const TabWidget({Key? key}) : super(key: key);

  @override
  State<TabWidget> createState() => _TabState();
}

class _TabState extends State<TabWidget> with Disposables {
  final _stage = Core.get<StageStore>();
  final _nav = Core.get<TopBarController>();

  StageTab _active = StageTab.home;

  @override
  void initState() {
    super.initState();
    //_stage.addOnValue(routeChanged, _updateRoute);
  }

  _updateRoute(StageRouteState route, Marker m) async {
    setState(() {
      if (_stage.route.isTab(StageTab.home)) {
        _active = StageTab.home;
      } else if (_stage.route.isTab(StageTab.activity)) {
        _active = StageTab.activity;
      } else if (_stage.route.isTab(StageTab.advanced)) {
        _active = StageTab.advanced;
      } else if (_stage.route.isTab(StageTab.settings)) {
        _active = StageTab.settings;
      }
    });
  }

  _tap(StageTab tab) async {
    // Instant UI feedback
    setState(() {
      _active = tab;
    });

    _nav.hackyManualPopToFirst();

    if (tab == StageTab.home) {
      // Already popped above
      _stage.setRoute(StageTab.home.name, Markers.userTap);
    } else if (tab == StageTab.activity) {
      Navigation.open(Paths.privacyPulse);
      _stage.setRoute(StageTab.activity.name, Markers.userTap);
    } else if (tab == StageTab.advanced) {
      Navigation.open(Paths.advanced);
      _stage.setRoute(StageTab.advanced.name, Markers.userTap);
    } else {
      Navigation.open(Paths.settings);
      _stage.setRoute(StageTab.settings.name, Markers.userTap);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: Stack(
        children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 25,
                sigmaY: 25,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: context.theme.panelBackground.withOpacity(0.2),
                  border: Border(
                    top: BorderSide(
                      width: 1,
                      color: context.theme.divider.withOpacity(0.05),
                    ),
                  ),
                ),
                height: 104,
                //color: context.theme.divider.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TabItem(
                    icon: Icons.shield_outlined,
                    title: "main tab home".i18n,
                    active: _active == StageTab.home,
                    onTap: () => _tap(StageTab.home)),
                TabItem(
                    icon: CupertinoIcons.chart_bar,
                    title: "main tab activity".i18n,
                    active: _active == StageTab.activity,
                    onTap: () => _tap(StageTab.activity)),
                TabItem(
                    icon: CupertinoIcons.cube_box,
                    title: "main tab advanced".i18n,
                    active: _active == StageTab.advanced,
                    onTap: () => _tap(StageTab.advanced)),
                TabItem(
                    icon: CupertinoIcons.settings,
                    title: "main tab settings".i18n,
                    active: _active == StageTab.settings,
                    onTap: () => _tap(StageTab.settings)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
