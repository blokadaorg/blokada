import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/modal/ui/bottom_sheet.dart';
import 'package:common/src/features/modal/ui/overlay.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/v6/widget/home_screen.dart';
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
