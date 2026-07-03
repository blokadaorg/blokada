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
    return GestureDetector(
      // When disabled, suppress every gesture callback so the press
      // highlight doesn't fire either — a no-op `onTap` would still let
      // the press animation play, reading as a broken button instead of
      // a disabled one.
      onTapDown: disabled ? null : _onTapDown,
      onTapUp: disabled ? null : _onTapUp,
      onTapCancel: disabled ? null : _depress,
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: widget.tapBorderRadius ?? BorderRadius.circular(12),
          color: pressed ? (widget.tapBgColor ?? pressColor(context)) : widget.bgColor,
        ),
        child: Padding(
          padding: widget.padding ?? const EdgeInsets.all(12.0),
          child: widget.child,
        ),
      ),
    );
  }
}
