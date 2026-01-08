import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/stats/stats.dart';
import 'package:common/src/platform/stats/delta_store.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/app_variants/v6/widget/home/stats/radial_chart.dart';
import 'package:countup/countup.dart';
import 'package:flutter/material.dart';

import 'package:common/src/shared/ui/minicard/chart.dart';

class HorizontalRadialSegment extends StatefulWidget {
  final UiStats stats;
  final StatsCounters? counters;
  final CounterDelta? counterDelta;
  final DailySeries? sparklineSeries;
  final bool statsReady;
  final bool deltaReady;

  const HorizontalRadialSegment({
    Key? key,
    required this.stats,
    this.counters,
    this.counterDelta,
    this.sparklineSeries,
    this.statsReady = true,
    this.deltaReady = true,
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
  RadialRing? _selectedRing;

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

  Widget _buildDeltaText(
    int? percent, {
    required bool negativeGood,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double fontSize = 12,
  }) {
    final display = percent == null || percent == 0 ? "" : "${percent > 0 ? "+" : ""}$percent%";
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Text(
        display,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color ?? Colors.grey,
        ),
      ),
    );
  }

  void _toggleSelection(RadialRing ring) {
    setState(() {
      if (_selectedRing == ring) {
        _selectedRing = null;
      } else {
        _selectedRing = ring;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _calculate();
    final selectedRing = _selectedRing;
    final blockedOpacity =
        selectedRing == null || selectedRing == RadialRing.blocked ? 1.0 : 0.4;
    final allowedOpacity =
        selectedRing == null || selectedRing == RadialRing.allowed ? 1.0 : 0.4;
    final blockedDeltaWeight = selectedRing == RadialRing.blocked
        ? FontWeight.w700
        : FontWeight.w500;
    final allowedDeltaWeight = selectedRing == RadialRing.allowed
        ? FontWeight.w700
        : FontWeight.w500;
    final blockedDeltaSize = selectedRing == RadialRing.blocked ? 13.0 : 12.0;
    final allowedDeltaSize = selectedRing == RadialRing.allowed ? 13.0 : 12.0;
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
                  statsReady: widget.statsReady,
                  deltaReady: widget.deltaReady,
                  selectedRing: selectedRing,
                  onRingTap: _toggleSelection,
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
                      child: AnimatedOpacity(
                        opacity: blockedOpacity,
                        duration: const Duration(milliseconds: 180),
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
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: allowedOpacity,
                        duration: const Duration(milliseconds: 180),
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
                      child: AnimatedOpacity(
                        opacity: blockedOpacity,
                        duration: const Duration(milliseconds: 180),
                        child: _buildDeltaText(
                          widget.counterDelta?.hasComparison == true
                              ? widget.counterDelta?.blockedPercent
                              : null,
                          negativeGood: false,
                          color: context.theme.textSecondary,
                          fontWeight: blockedDeltaWeight,
                          fontSize: blockedDeltaSize,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: allowedOpacity,
                        duration: const Duration(milliseconds: 180),
                        child: _buildDeltaText(
                          widget.counterDelta?.hasComparison == true
                              ? widget.counterDelta?.allowedPercent
                              : null,
                          negativeGood: true,
                          color: context.theme.textSecondary,
                          fontWeight: allowedDeltaWeight,
                          fontSize: allowedDeltaSize,
                        ),
                      ),
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
