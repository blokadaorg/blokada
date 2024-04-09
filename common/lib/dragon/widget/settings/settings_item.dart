import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:flutter/material.dart';

class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const SettingsItem(
      {super.key, required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CommonClickable(
      tapBorderRadius: BorderRadius.zero,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: context.theme.divider),
          SizedBox(width: 10),
          Text(text, style: TextStyle(fontSize: 14)),
          Spacer(),
          Icon(Icons.chevron_right, size: 24, color: context.theme.divider),
        ],
      ),
    );
  }
}
