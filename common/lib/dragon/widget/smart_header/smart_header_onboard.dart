import 'package:flutter/material.dart';

class SmartHeaderOnboard extends StatefulWidget {
  final bool opened;

  const SmartHeaderOnboard({Key? key, required this.opened}) : super(key: key);

  @override
  State<SmartHeaderOnboard> createState() => SmartHeaderOnboardState();
}

class SmartHeaderOnboardState extends State<SmartHeaderOnboard>
    with TickerProviderStateMixin {
  late final _ctrl = AnimationController(
    duration: const Duration(milliseconds: 400),
    vsync: this,
  );

  late final _scale = Tween(begin: 1.0, end: 8.0).animate(CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeInOut,
  ));

  late final _pos = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
    parent: _ctrl,
    curve: Curves.decelerate,
  ));

  @override
  void didUpdateWidget(SmartHeaderOnboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.opened != oldWidget.opened) {
      if (widget.opened) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints size) {
            return Column(
              children: [
                SizedBox(
                  height: 400,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 16 + _pos.value * 200,
                        left: 16 +
                            (_pos.value * size.maxWidth) / 2.0 -
                            _pos.value * 40,
                        child: Transform.scale(
                          scale: _scale.value,
                          alignment: Alignment.center,
                          child: _buildLogo(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          });
        });
  }

  Widget _buildLogo(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Image.asset(
          "assets/images/family-logo.png",
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
