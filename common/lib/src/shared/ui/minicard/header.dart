import 'package:flutter/material.dart';

import '../theme.dart';

/// The title row of a [MiniCard]: an icon, the title and an optional
/// chevron or label on the right that hints the card opens more.
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
              // Wraps rather than ellipsizing: with large text or long
              // translations a cut title ("Letzten …") loses its meaning.
              Expanded(
                child: Text(
                  text,
                  style: context.theme.text.body.semibold.copyWith(color: textColor ?? color),
                ),
              ),
            ],
          ),
        ),
        if (chevronText != null || chevronIcon != null)
          Row(
            children: [
              if (chevronText != null)
                Text(chevronText!, style: TextStyle(color: context.theme.textSecondary)),
              if (chevronIcon != null) Icon(chevronIcon, color: context.theme.textSecondary),
            ],
          ),
      ],
    );
  }
}
