import 'package:common/common/navigation.dart';
import 'package:common/common/widget/modal/bottom_sheet.dart';
import 'package:common/common/widget/modal/overlay.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/family/widget/home/animated_bg.dart';
import 'package:common/family/widget/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FamilyMainScreen extends StatefulWidget {
  final TopBarController ctrl;
  final NavigationPopObserver nav;

  FamilyMainScreen({
    super.key,
    required this.ctrl,
    required this.nav,
  });

  @override
  State<StatefulWidget> createState() => FamilyMainScreenState();
}

class FamilyMainScreenState extends State<FamilyMainScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
                      homeContent: const FamilyHomeScreen());
                },
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TopCommonBar(),
            ),
            const BottomManagerSheet(),
            const OverlaySheet(),
          ],
        ),
      ),
    );
  }
}
