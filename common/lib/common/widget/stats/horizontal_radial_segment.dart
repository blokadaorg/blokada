import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/v6/widget/home/stats/radial_chart.dart';
import 'package:countup/countup.dart';
import 'package:flutter/material.dart';

import '../../../../common/widget/minicard/chart.dart';

class HorizontalRadialSegment extends StatefulWidget {
  final UiStats stats;

  const HorizontalRadialSegment({Key? key, required this.stats}) : super(key: key);

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
    allowed = widget.stats.dayAllowed.toDouble();
    blocked = widget.stats.dayBlocked.toDouble();
    total = widget.stats.dayTotal.toDouble();
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
                child: RadialChart(stats: widget.stats),
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
                          ),
                        ],
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
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}