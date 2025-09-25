import 'package:common/common/widget/theme.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:flutter/cupertino.dart';

import 'horizontal_radial_segment.dart';

class PrivacyPulse extends StatelessWidget {
  final UiStats stats;

  const PrivacyPulse({Key? key, required this.stats}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.checkmark_shield,
                  color: context.theme.textPrimary,
                  size: 36,
                ),
                SizedBox(width: 12),
                Text(
                  "Privacy Pulse",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.theme.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "Recent activity and protection level for this device",
              style: TextStyle(
                fontSize: 14,
                color: context.theme.textSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        // Main content using HorizontalRadialSegment
        HorizontalRadialSegment(stats: stats),
      ],
    );
  }
}
