import 'package:flutter/material.dart';

class Sliding extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(-5.0, 0.0),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOut.flipped,
  ));

  Sliding({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: child,
    );
  }
}
