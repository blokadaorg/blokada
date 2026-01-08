import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/stats/stats.dart';
import 'package:common/src/platform/stats/delta_store.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:flutter/cupertino.dart';

import 'horizontal_radial_segment.dart';

class PrivacyPulseCharts extends StatelessWidget {
  final UiStats stats;
  final Widget? trailing;
  final StatsCounters? counters;
  final CounterDelta? counterDelta;
  final DailySeries? sparklineSeries;
  final bool statsReady;
  final bool deltaReady;

  const PrivacyPulseCharts({
    Key? key,
    required this.stats,
    this.trailing,
    this.counters,
    this.counterDelta,
    this.sparklineSeries,
    this.statsReady = true,
    this.deltaReady = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.checkmark_shield,
                    color: context.theme.textPrimary,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      "privacy pulse section header".i18n,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.theme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "privacy pulse brief".i18n,
          style: TextStyle(
            fontSize: 14,
            color: context.theme.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        // Main content using HorizontalRadialSegment
        HorizontalRadialSegment(
          stats: stats,
          counters: counters,
          counterDelta: counterDelta,
          sparklineSeries: sparklineSeries,
          statsReady: statsReady,
          deltaReady: deltaReady,
        ),
      ],
    );
  }

}
