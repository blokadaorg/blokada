import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:flutter/material.dart';

class ActionItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const ActionItem(
      {super.key, required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CommonClickable(
      onTap: onTap,
      tapBorderRadius: BorderRadius.zero,
      child: Row(
        children: [
          Icon(icon, size: 24, color: context.theme.divider),
          SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 16)),
          Spacer(),
        ],
      ),
    );
  }
}
