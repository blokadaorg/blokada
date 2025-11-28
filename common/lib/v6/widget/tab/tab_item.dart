import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/unread_badge.dart';
import 'package:flutter/material.dart';

class TabItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback? onTap;
  final bool showUnreadBadge;

  const TabItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.active,
    this.onTap,
    this.showUnreadBadge = false,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => TabItemState();
}

class TabItemState extends State<TabItem> {
  @override
  Widget build(BuildContext context) {
    final color =
        widget.active ? context.theme.accent : context.theme.textPrimary;

    return GestureDetector(
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
  }
}
