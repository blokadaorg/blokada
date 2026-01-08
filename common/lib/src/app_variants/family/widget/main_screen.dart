import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/modal/ui/bottom_sheet.dart';
import 'package:common/src/features/modal/ui/overlay.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/widget/home/animated_bg.dart';
import 'package:common/src/app_variants/family/widget/home/home_screen.dart';
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
