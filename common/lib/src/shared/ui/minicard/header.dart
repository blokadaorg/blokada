import 'package:flutter/material.dart';

import '../theme.dart';

class MiniCardHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  /// Header text colour when it should differ from the icon, e.g. a
  /// contrast-safe text token next to a bright palette icon.
  final Color? textColor;
  final IconData? chevronIcon;
  final String? chevronText;

  const MiniCardHeader({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    this.textColor,
    this.chevronIcon,
    this.chevronText,
  });

  @override
  Widget build(BuildContext context) {
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
                  style: context.theme.text.body.semibold.copyWith(color: textColor ?? color),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        if (chevronText != null || chevronIcon != null)
          Row(
            children: [
              if (chevronText != null)
                Text(chevronText!,
                    style: TextStyle(color: context.theme.textSecondary)),
              if (chevronIcon != null)
                Icon(chevronIcon, color: context.theme.textSecondary),
            ],
          )
      ],
    );
  }
}
