import 'package:common/src/shared/ui/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';

class StandardRoute extends MaterialWithModalsPageRoute {
  StandardRoute(
      {required WidgetBuilder builder, required RouteSettings settings})
      : super(builder: builder, settings: settings);

  late TopBarController ctrl;
  bool _listeningToSecondary = false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  void _updateTopBar() {
    final v = secondaryAnimation?.value;
    if (v == null || v > 1.0 || v < 0.0) return;
    ctrl.updateUserGesturePos(v);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    ctrl = Provider.of<TopBarController>(context, listen: false);

    // buildTransitions runs on every rebuild; listen once, stop in dispose.
    if (!_listeningToSecondary) {
      secondaryAnimation.addListener(_updateTopBar);
      _listeningToSecondary = true;
    }

    return AnimatedBuilder(
      animation: secondaryAnimation,
      builder: (context, c) {
        return super
            .buildTransitions(context, animation, secondaryAnimation, child);
      },
      child: child,
    );
  }

  @override
  void dispose() {
    secondaryAnimation?.removeListener(_updateTopBar);
    super.dispose();
  }
}
