import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

class CommonClickable extends StatefulWidget {
  /// Tap handler. Pass `null` to render the widget non-interactive — the
  /// press-highlight animation is suppressed too, so a disabled state
  /// reads as disabled in both visual and gesture terms.
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final Color? bgColor;
  final Color? tapBgColor;
  final BorderRadius? tapBorderRadius;

  /// Outline for the fill and press highlight, replacing the rounded
  /// rectangle of [tapBorderRadius]. Exists so bar buttons on iOS can take
  /// the system's superellipse bubble while every other caller keeps the
  /// rectangle.
  final OutlinedBorder? shape;
  final Widget child;

  const CommonClickable({
    super.key,
    required this.onTap,
    required this.child,
    this.padding,
    this.bgColor,
    this.tapBgColor,
    this.tapBorderRadius,
    this.shape,
  });

  @override
  State<StatefulWidget> createState() => CommonClickableState();
}

const _pressHighlightDuration = Duration(milliseconds: 100);
const _releaseHighlightDuration = Duration(milliseconds: 200);

class CommonClickableState extends State<CommonClickable> {
  /// Press-highlight color, exposed so list rows can paint a persistent
  /// selection state in exactly the same color as the tap feedback.
  static Color pressColor(BuildContext context) => context.theme.shadow.withOpacity(0.5);

  bool pressed = false;

  _onTapDown(TapDownDetails d) {
    if (!mounted) return;
    setState(() {
      pressed = true;
    });
  }

  _onTapUp(TapUpDetails d) => _depress();

  _depress() {
    Future.delayed(_pressHighlightDuration, () {
      if (!mounted) return;
      setState(() {
        pressed = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final color = pressed ? (widget.tapBgColor ?? pressColor(context)) : widget.bgColor;
    return GestureDetector(
      // When disabled, suppress every gesture callback so the press
      // highlight doesn't fire either — a no-op `onTap` would still let
      // the press animation play, reading as a broken button instead of
      // a disabled one.
      onTapDown: disabled ? null : _onTapDown,
      onTapUp: disabled ? null : _onTapUp,
      onTapCancel: disabled ? null : _depress,
      onTap: widget.onTap,
      // Rows highlight without the shrink cards and buttons get from Touch.
      child: AnimatedContainer(
        duration: pressed ? _pressHighlightDuration : _releaseHighlightDuration,
        curve: Curves.easeInOut,
        decoration: widget.shape != null
            ? ShapeDecoration(shape: widget.shape!, color: color)
            : BoxDecoration(
                borderRadius: widget.tapBorderRadius ?? BorderRadius.circular(12),
                color: color,
              ),
        child: Padding(padding: widget.padding ?? const EdgeInsets.all(12.0), child: widget.child),
      ),
    );
  }
}
