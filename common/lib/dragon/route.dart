import 'package:common/dragon/widget/common/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';

class StandardRoute extends MaterialWithModalsPageRoute {
  StandardRoute(
      {required WidgetBuilder builder, required RouteSettings settings})
      : super(builder: builder, settings: settings);

  late TopBarController ctrl;

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

    secondaryAnimation.addListener(_updateTopBar);

    // Use a builder that removes the listener when the animation widget disposes
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
  bool didPop(dynamic result) {
    animation?.removeListener(_updateTopBar);
    return super.didPop(result);
  }
}
