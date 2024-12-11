import 'package:common/common/widget/theme.dart';
import 'package:flutter/material.dart';

class TabItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback? onTap;

  const TabItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.active,
    this.onTap,
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
              Icon(
                widget.icon,
                color: color,
              ),
              Text(widget.title, style: TextStyle(color: color))
            ],
          ),
        ),
      ),
    );
  }
}
