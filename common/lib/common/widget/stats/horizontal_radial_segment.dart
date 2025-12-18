import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/stats/delta_store.dart';
import 'package:common/platform/stats/stats.dart';
import 'package:common/v6/widget/home/stats/radial_chart.dart';
import 'package:countup/countup.dart';
import 'package:flutter/material.dart';

import '../../../../common/widget/minicard/chart.dart';

class HorizontalRadialSegment extends StatefulWidget {
  final UiStats stats;
  final StatsCounters? counters;
  final CounterDelta? counterDelta;
  final DailySeries? sparklineSeries;

  const HorizontalRadialSegment({
    Key? key,
    required this.stats,
    this.counters,
    this.counterDelta,
    this.sparklineSeries,
  })
      : super(key: key);

  @override
  State<StatefulWidget> createState() => HorizontalRadialSegmentState();
}

class HorizontalRadialSegmentState extends State<HorizontalRadialSegment> {
  var blocked = 0.0;
  var allowed = 0.0;
  var total = 0.0;
  var lastBlocked = 0.0;
  var lastAllowed = 0.0;
  var lastTotal = 0.0;

  _calculate() {
    lastAllowed = allowed;
    lastBlocked = blocked;
    lastTotal = total;
    final counters = widget.counters;
    if (counters != null) {
      allowed = counters.allowed.toDouble();
      blocked = counters.blocked.toDouble();
      total = counters.total.toDouble();
    } else {
      allowed = widget.stats.dayAllowed.toDouble();
      blocked = widget.stats.dayBlocked.toDouble();
      total = widget.stats.dayTotal.toDouble();
    }
  }

  Widget _buildDeltaText(int? percent, {required bool negativeGood, Color? color}) {
    final display = percent == null || percent == 0 ? "" : "${percent > 0 ? "+" : ""}$percent%";
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Text(
        display,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color ?? Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _calculate();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Radial chart - fixed width
        ClipRect(
          child: Center(
              child: Transform.scale(
                scale: 1.3, // Scale up to reduce apparent padding
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: RadialChart(
                    stats: widget.stats,
                    counterDelta: widget.counterDelta,
                  ),
                ),
              ),
            ),
          ),
        SizedBox(width: 16),
        // Right side content - remaining space
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // First row: blocked/allowed counters
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("stats label blocked".i18n,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Color(0xffff3b30),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              )),
                          Countup(
                            begin: lastBlocked,
                            end: blocked,
                            duration: const Duration(seconds: 1),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("stats label allowed".i18n,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Color(0xff33c75a),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              )),
                          Countup(
                            begin: lastAllowed,
                            end: allowed,
                            duration: const Duration(seconds: 1),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Delta badges below counters
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4, right: 4, bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDeltaText(widget.counterDelta?.blockedPercent,
                          negativeGood: false, color: context.theme.textSecondary),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildDeltaText(widget.counterDelta?.allowedPercent,
                          negativeGood: true, color: context.theme.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Divider(
                color: context.theme.divider,
                height: 1,
                thickness: 0.2,
              ),
              SizedBox(height: 8),
              // Second row: line chart
              Expanded(
                child: MiniCardChart(
                  stats: widget.stats,
                  color: Color(0xff33c75a),
                  animate: false,
                  height: 42,
                  seriesValues: widget.sparklineSeries?.values,
                  seriesEnd: widget.sparklineSeries?.end,
                  seriesStep: widget.sparklineSeries?.step,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
