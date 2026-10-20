import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

/// Shown in place of a stats section whose fetch failed, so a failure no
/// longer reads as "nothing to show yet", with a way to try again.
class StatsError extends StatelessWidget {
  final VoidCallback onRetry;

  const StatsError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "alert error header".i18n,
              style: TextStyle(color: context.theme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 4),
            CommonClickable(
              onTap: onRetry,
              child: Text(
                "universal action try again".i18n,
                style: context.theme.linkStyle(const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
