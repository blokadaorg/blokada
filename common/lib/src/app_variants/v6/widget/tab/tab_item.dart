import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/shared/ui/unread_badge.dart';
import 'package:flutter/material.dart';

class TabItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback? onTap;
  final bool showUnreadBadge;

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
    this.automationId,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => TabItemState();
}

class TabItemState extends State<TabItem> {
  @override
  Widget build(BuildContext context) {
    final color = widget.active ? context.theme.accent : context.theme.textPrimary;

    final child = GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(0),
        child: SizedBox(
          height: 48,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    widget.icon,
                    color: color,
                  ),
                  if (widget.showUnreadBadge)
                    const Positioned(
                      right: -8,
                      top: -6,
                      child: UnreadBadge(),
                    ),
                ],
              ),
              Text(widget.title, style: TextStyle(color: color), textAlign: TextAlign.center),
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
