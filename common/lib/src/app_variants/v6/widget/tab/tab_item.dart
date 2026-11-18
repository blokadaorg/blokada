import 'package:common/src/shared/ui/text_scale.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/shared/ui/unread_badge.dart';
import 'package:flutter/material.dart';

class TabItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback? onTap;
  final bool showUnreadBadge;

  /// The icon beside the title rather than above it, for full-width rows.
  final bool horizontal;

  /// Stable semantics identifier used by automation because these tab buttons
  /// are custom Flutter gestures rather than native tab bar controls.
  final String? automationId;

  const TabItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.active,
    this.onTap,
    this.showUnreadBadge = false,
    this.horizontal = false,
    this.automationId,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => TabItemState();
}

class TabItemState extends State<TabItem> {
  @override
  Widget build(BuildContext context) {
    final color = widget.active ? context.theme.accent : context.theme.textPrimary;

    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(widget.icon, color: color),
        if (widget.showUnreadBadge) const Positioned(right: -8, top: -6, child: UnreadBadge()),
      ],
    );

    final child = GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(0),
        // Grows with large text, whose title can wrap.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: widget.horizontal
              ? Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(
                      child: WordFitText(widget.title, style: TextStyle(color: color)),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    Text(
                      widget.title,
                      style: TextStyle(color: color),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );

    final automationId = widget.automationId;
    if (automationId == null) return child;

    // MergeSemantics collapses the GestureDetector + Icon/Text column into a
    // single node so the identifier reaches the iOS accessibility element
    // Appium queries (otherwise it stays on a non-hittable container).
    return MergeSemantics(
      child: Semantics(
        identifier: automationId,
        label: widget.title,
        button: widget.onTap != null,
        selected: widget.active,
        child: child,
      ),
    );
  }
}
