import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../util/trace.dart';

class BlurBackground extends StatefulWidget {
  final bool Function()? canClose;
  final VoidCallback? onClosed;
  final Widget child;

  const BlurBackground({
    Key? key,
    this.onClosed,
    this.canClose,
    required this.child,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => BlurBackgroundState();
}

class BlurBackgroundState extends State<BlurBackground>
    with TickerProviderStateMixin, TraceOrigin {
  final _animDuration = const Duration(milliseconds: 400);
  double _opacity = 0.0;

  late final AnimationController _ctrlBlur;
  late final Animation<double> _animBlur;

  @override
  void initState() {
    super.initState();

    _ctrlBlur = AnimationController(
      vsync: this,
      duration: _animDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          widget.onClosed?.call();
        }
      });

    _animBlur = Tween<double>(
      begin: 0.0,
      end: 25.0,
    ).animate(_ctrlBlur);

    // Show the view soon after creating
    Future.delayed(const Duration(milliseconds: 1), () {
      setState(() {
        _opacity = 1.0;
      });
      _ctrlBlur.forward();
    });
  }

  @override
  void dispose() {
    _ctrlBlur.dispose();
    super.dispose();
  }

  animateToClose() {
    if (widget.canClose?.call() ?? true) {
      // End of this animation will call the route change
      _ctrlBlur.reverse();
      setState(() {
        _opacity = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (dragEndDetails) {
        if (dragEndDetails.primaryVelocity! < 0) {
          animateToClose();
        }
      },
      child: AnimatedBuilder(
          animation: _animBlur,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _animBlur.value,
                    sigmaY: _animBlur.value,
                  ),
                  child: AnimatedOpacity(
                    opacity: _opacity,
                    duration: _animDuration,
                    child: Container(
                      color: Colors.black.withOpacity(0.75),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _opacity,
                  duration: _animDuration,
                  child: widget.child,
                ),
              ],
            );
          }),
    );
  }
}
