import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

/// Detail-pane empty state for hosts that keep the split visible before a
/// selection (Activity, Settings): a big dimmed icon and a header telling
/// the user to pick something on the left. Copy is English-only until a
/// key lands in the translate submodule (tracked follow-up).
class DetailPanePlaceholder extends StatelessWidget {
  final IconData icon;
  final String? text;

  const DetailPanePlaceholder({
    super.key,
    this.icon = Icons.touch_app_outlined,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.theme.textSecondary.withOpacity(0.3);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 96, color: color),
            if (text != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  text!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
