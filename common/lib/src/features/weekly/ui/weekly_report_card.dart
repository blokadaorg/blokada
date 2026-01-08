import 'package:common/src/shared/ui/common_card.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A reusable card for weekly change summaries on the Privacy Pulse screen.
///
/// Uses the same aesthetics as other Privacy Pulse cards, with an optional tap
/// action and dismiss button. The main content area is a free-form widget so
/// complex layouts can be embedded.
class WeeklyReportCard extends StatelessWidget {
  final String title;
  final Widget content;
  final String? time;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const WeeklyReportCard({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.time,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return CommonCard(
      bgColor: backgroundColor ?? theme.bgColorCard,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          if (onTap != null)
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTap,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: iconColor ?? theme.accent,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      content,
                      if (time != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          time!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            Positioned(
              top: 6,
              right: 6,
              child: CommonClickable(
                onTap: onDismiss!,
                padding: const EdgeInsets.all(8),
                tapBorderRadius: BorderRadius.circular(8),
                child: Icon(
                  CupertinoIcons.clear,
                  size: 18,
                  color: theme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
