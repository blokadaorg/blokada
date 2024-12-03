import 'package:common/common/navigation.dart';
import 'package:common/common/widget/overlay.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/family/widget/home/animated_bg.dart';
import 'package:common/v6/widget/home_screen.dart';
import 'package:common/v6/widget/tab/tab.dart';
import 'package:common/v6/widget/tab/tab_bar_compensation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class V6MainScreen extends StatefulWidget {
  final TopBarController ctrl;
  final NavigationPopObserver nav;

  V6MainScreen({
    super.key,
    required this.ctrl,
    required this.nav,
  });

  @override
  State<StatefulWidget> createState() => V6MainScreenState();
}

class V6MainScreenState extends State<V6MainScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChangeNotifierProvider(
        create: (context) => widget.ctrl,
        child: Stack(
          children: [
            const FamilyAnimatedBg(),
            Padding(
              padding: EdgeInsets.only(
                  bottom: PlatformInfo().isSmallAndroid(context) ? 44 : 0),
              child: Navigator(
                key: widget.ctrl.navigatorKey,
                observers: [widget.ctrl, widget.nav],
                onGenerateRoute: (settings) {
                  return Navigation().generateRoute(context, settings,
                      homeContent: const V6HomeScreen());
                },
              ),
            ),
            (context.isKeyboardOpened)
                ? Container()
                : const Column(
                    children: [
                      Spacer(),
                      TabWidget(),
                    ],
                  ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TopCommonBar(),
            ),
            const OverlaySheet(),
          ],
        ),
      ),
    );
  }
}
