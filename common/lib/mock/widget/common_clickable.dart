import 'package:common/common/widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CommonClickable extends StatefulWidget {
  final VoidCallback onTap;
  final EdgeInsets? padding;
  final Color? bgColor;
  final Color? tapBgColor;
  final BorderRadius? tapBorderRadius;
  final Widget child;

  const CommonClickable({
    super.key,
    required this.onTap,
    required this.child,
    this.padding,
    this.bgColor,
    this.tapBgColor,
    this.tapBorderRadius,
  });

  @override
  State<StatefulWidget> createState() => CommonClickableState();
}

const _pressHighlightDuration = Duration(milliseconds: 100);

class CommonClickableState extends State<CommonClickable> {
  bool pressed = false;

  _onTapDown(TapDownDetails d) {
    setState(() {
      pressed = true;
    });
  }

  _onTapUp(TapUpDetails d) => _depress();

  _depress() {
    Future.delayed(_pressHighlightDuration, () {
      setState(() {
        pressed = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _depress,
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: widget.tapBorderRadius ?? BorderRadius.circular(12),
          color: pressed
              ? (widget.tapBgColor ?? context.theme.shadow.withOpacity(0.5))
              : widget.bgColor,
        ),
        child: Padding(
          padding: widget.padding ?? const EdgeInsets.all(12.0),
          child: widget.child,
        ),
      ),
    );
  }
}
