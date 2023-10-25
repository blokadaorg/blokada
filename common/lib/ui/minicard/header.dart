import 'package:flutter/material.dart';

import '../theme.dart';

class MiniCardHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final IconData? chevronIcon;

  const MiniCardHeader({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    this.chevronIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        if (chevronIcon != null) Icon(chevronIcon, color: theme.textSecondary)
      ],
    );
  }
}
