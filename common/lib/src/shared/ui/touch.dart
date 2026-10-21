import 'package:common/src/shared/ui/motion.dart';
import 'package:flutter/material.dart';

/// Press feedback for cards and buttons: a highlight from [decorationBuilder]
/// and a shrink to 97%, about 100 ms in and 200 ms out. With Reduce Motion,
/// highlight only.
class Touch extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxValue;
  final BoxDecoration Function(double) decorationBuilder;
  final VoidCallback? onTap;
  final VoidCallback? onLongTap;

  /// Whether the child shrinks while pressed. Off for overlays on a painted
  /// control, like the power button.
  final bool shrink;

  const Touch({
    super.key,
    required this.child,
    this.maxValue = 0.6,
    required this.decorationBuilder,
    this.padding,
    this.onTap,
    this.onLongTap,
    this.shrink = true,
  });

  @override
  State<StatefulWidget> createState() => TouchState();
}

const _pressScale = 0.97;

class TouchState extends State<Touch> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOut, reverseCurve: Curves.easeIn)
      ..addListener(() {
        setState(() {
          // Rebuild the widget tree
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _depress() {
    if (_isInteractive()) {
      // A short timer so that the button doesn't flash
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          if (_isInteractive()) {
            _controller.forward();
          }
        });
      },
      onTapUp: (details) {
        _depress();
      },
      onTapCancel: () {
        _depress();
      },
      onTap: () => widget.onTap?.call(),
      onLongPress: () => widget.onLongTap?.call(),
      child: Transform.scale(
        scale: widget.shrink && !Motion.reduced(context) ? 1 - (1 - _pressScale) * _anim.value : 1,
        child: Container(
          decoration: widget.decorationBuilder(_anim.value * widget.maxValue),
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }

  bool _isInteractive() => widget.onTap != null || widget.onLongTap != null;
}
