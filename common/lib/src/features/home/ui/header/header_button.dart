import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/shared/ui/touch.dart';
import 'package:common/src/shared/ui/unread_badge.dart';
import 'package:flutter/material.dart';

class SmartHeaderButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? iconWidget;
  final bool unread;
  final Color? bgColor;

  /// Read by VoiceOver/TalkBack in place of the icon, which has no text.
  final String? label;

  const SmartHeaderButton({
    super.key,
    this.onTap,
    this.icon,
    this.iconWidget,
    this.unread = false,
    this.bgColor,
    this.label,
  });

  @override
  State<StatefulWidget> createState() => SmartHeaderButtonState();
}

class SmartHeaderButtonState extends State<SmartHeaderButton> {
  @override
  Widget build(BuildContext context) {
    final button = Stack(
      alignment: Alignment.topRight,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6.0, top: 6.0),
          child: Container(
            decoration: BoxDecoration(
              color: widget.bgColor ?? context.theme.textPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 48,
              height: 48,
              child:
                  widget.iconWidget ??
                  Touch(
                    onTap: widget.onTap,
                    decorationBuilder: (value) {
                      return BoxDecoration(
                        color: context.theme.bgMiniCard.withOpacity(value * 0.25),
                        borderRadius: BorderRadius.circular(12),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        widget.icon,
                        color: widget.bgColor == null ? Colors.white : context.theme.textPrimary,
                      ),
                    ),
                  ),
            ),
          ),
        ),
        widget.unread ? const UnreadBadge() : Container(),
      ],
    );
    final label = widget.label;
    if (label == null) return button;
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: button,
    );
  }
}
