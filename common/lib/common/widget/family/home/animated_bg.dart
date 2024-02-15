import 'package:common/common/widget.dart';
import 'package:flutter/material.dart';

class AnimatedBg extends StatefulWidget {
  const AnimatedBg({Key? key}) : super(key: key);

  @override
  State<AnimatedBg> createState() => AnimatedBgState();
}

class AnimatedBgState extends State<AnimatedBg> with TickerProviderStateMixin {
  late final _ctrl = AnimationController(
    duration: const Duration(seconds: 15),
    vsync: this,
  );

  late final _anim = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeInOut,
  ));

  @override
  void initState() {
    super.initState();
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xff4ae5f6),
                  Color(0xff3c8cff),
                  Color(0xff3c8cff),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomCenter,
                  colors: [
                    //Colors.transparent,
                    Color(0xffe450cd).withOpacity((1 - _anim.value) * 0.9),
                    Color(0xffe450cd).withOpacity(0.1 + _anim.value * 0.9),
                    Color(0xffe450cd),
                  ],
                  stops: [0.1, 0.7, 1.0],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      context.theme.bgColorHome1.withOpacity(0.4 * _anim.value),
                      context.theme.bgColorHome1.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }
}
