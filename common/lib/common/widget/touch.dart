part of '../widget.dart';

class Touch extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxValue;
  final BoxDecoration Function(double) decorationBuilder;
  final VoidCallback? onTap;
  final VoidCallback? onLongTap;

  const Touch(
      {super.key,
      required this.child,
      this.maxValue = 0.6,
      required this.decorationBuilder,
      this.padding,
      this.onTap,
      this.onLongTap});

  @override
  State<StatefulWidget> createState() => TouchState();
}

// TODO: use AnimatedWidgetBaseState
class TouchState extends State<Touch> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _anim = Tween<double>(begin: 0, end: widget.maxValue).animate(_controller)
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
        _controller.duration = const Duration(milliseconds: 300);
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
            _controller.duration = const Duration(milliseconds: 50);
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
      child: Container(
        decoration: widget.decorationBuilder(_anim.value),
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }

  bool _isInteractive() => widget.onTap != null || widget.onLongTap != null;
}
