import 'package:common/common/widget.dart';
import 'package:flutter/material.dart';

import 'common_clickable.dart';

class CommonItem extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String text;
  final Widget trailing;
  final bool chevron;

  const CommonItem({
    super.key,
    required this.onTap,
    required this.icon,
    required this.text,
    required this.trailing,
    this.chevron = true,
  });

  @override
  State<StatefulWidget> createState() => CommonItemState();
}

class CommonItemState extends State<CommonItem> {
  @override
  Widget build(BuildContext context) {
    return CommonClickable(
      onTap: widget.onTap,
      padding: const EdgeInsets.only(top: 14, bottom: 14, left: 12, right: 8),
      tapBorderRadius: BorderRadius.zero,
      child: Row(
        children: [
          Icon(widget.icon, color: context.theme.divider, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.text,
              style: TextStyle(
                color: context.theme.textPrimary,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          widget.trailing,
          widget.chevron
              ? Icon(Icons.chevron_right,
                  size: 24, color: context.theme.divider)
              : Container(),
        ],
      ),
    );
  }
}
