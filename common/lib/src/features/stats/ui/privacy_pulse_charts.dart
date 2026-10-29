import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/platform/stats/delta_store.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/shared/ui/placeholder.dart';
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
  final ToplistRange range;

  /// Drawn instead of the charts when their numbers failed to load.
  final Widget? error;

  const PrivacyPulseCharts({
    Key? key,
    required this.stats,
    this.trailing,
    this.counters,
    this.counterDelta,
    this.sparklineSeries,
    this.statsReady = true,
    this.deltaReady = true,
    this.range = ToplistRange.daily,
    this.error,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.checkmark_shield, color: context.theme.textPrimary, size: 36),
            // The trailing control gets the rest of the row, right-aligned,
            // so with large text it fits instead of running off the edge.
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // One line on what the numbers say, full width so it doesn't wrap
        // beside the range switch.
        _buildInsight(context),
        const SizedBox(height: 24),
        // Main content using HorizontalRadialSegment
        error ??
            HorizontalRadialSegment(
              stats: stats,
              range: range,
              counters: counters,
              counterDelta: counterDelta,
              sparklineSeries: sparklineSeries,
              statsReady: statsReady,
              deltaReady: deltaReady,
            ),
      ],
    );
  }

  /// The blocked count for the range, and how it compares with the period
  /// before when that is known, like "36 blocked in 24 h · 12% fewer than
  /// the 24 h before". Counts only.
  @visibleForTesting
  static String insight({
    required StatsCounters counters,
    required ToplistRange range,
    CounterDelta? delta,
  }) {
    final blocked = counters.blocked;
    final count =
        (blocked == 1 ? "privacy pulse insight blocked one" : "privacy pulse insight blocked many")
            .i18n
            .withParams(
              StatsStoreBase.formatCounter(blocked),
              range == ToplistRange.daily ? "stats range 24h".i18n : "stats range 7d".i18n,
            );

    final percent = delta?.hasComparison == true ? delta!.blockedPercent : 0;
    if (percent == 0) return count;
    final weekly = range == ToplistRange.weekly;
    final comparison =
        (percent < 0
                ? (weekly ? "privacy pulse insight fewer 7d" : "privacy pulse insight fewer 24h")
                : (weekly ? "privacy pulse insight more 7d" : "privacy pulse insight more 24h"))
            .i18n
            .withParams(percent.abs());
    return "$count · $comparison";
  }

  Widget _buildInsight(BuildContext context) {
    final counters = this.counters;
    if (counters == null) {
      if (error != null) return const SizedBox.shrink();
      return const LoadingPlaceholder(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: PlaceholderBar(width: 160, height: 16),
        ),
      );
    }
    return Text(
      insight(counters: counters, range: range, delta: deltaReady ? counterDelta : null),
      style: context.theme.text.body.semibold.copyWith(color: context.theme.textPrimary),
    );
  }
}
