import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:flutter/cupertino.dart';

/// A reusable card for weekly change summaries on the Privacy Pulse screen.
///
/// Mirrors the existing card aesthetics: rounded `CommonCard` background,
/// primary/secondary text colors from the theme, and an optional CTA + dismiss.
class WeeklyReportCard extends StatelessWidget {
  final String title;
  final String description;
  final String? time;
  final String? ctaLabel;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onCtaTap;
  final VoidCallback? onDismiss;

  const WeeklyReportCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.time,
    this.ctaLabel,
    this.onCtaTap,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: iconColor ?? theme.accent,
                  size: 42,
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
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      if (time != null || (ctaLabel != null && onCtaTap != null)) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (time != null)
                              Expanded(
                                child: Text(
                                  time!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            if (ctaLabel != null && onCtaTap != null)
                              CommonClickable(
                                onTap: onCtaTap!,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                tapBorderRadius: BorderRadius.circular(8),
                                child: Text(
                                  ctaLabel!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.accent,
                                  ),
                                ),
                              ),
                          ],
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
