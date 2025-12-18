import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/stats/delta_store.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

enum RadialRing { allowed, blocked }

class RadialChart extends StatelessWidget {
  final UiStats stats;
  final CounterDelta? counterDelta;
  final bool statsReady;
  final bool deltaReady;
  final RadialRing? selectedRing;
  final ValueChanged<RadialRing>? onRingTap;

  RadialChart({
    Key? key,
    required this.stats,
    this.counterDelta,
    this.statsReady = true,
    this.deltaReady = true,
    this.selectedRing,
    this.onRingTap,
  }) : super(key: key) {
    _convert();
  }

  late _ChartData allowedData;
  late _ChartData blockedData;
  CircularSeriesController? _chartSeriesController;

  List<Color> colorsRed = <Color>[
    const Color(0xffff7a6c),
    const Color(0xffff3b30),
    const Color(0xffde342a),
  ];

  List<Color> colorsGreen = <Color>[
    const Color(0xff61d981),
    const Color(0xff2fb653),
    const Color(0xff17933a),
  ];

  List<double> stops = <double>[
    0.0,
    0.6,
    1.0,
  ];

  @visibleForTesting
  static double gaugeFillFromDelta(int percent) {
    final fill = 50 + (percent / 2);
    return fill.clamp(0, 100).toDouble();
  }

  void _convert() {
    final delta = counterDelta;
    final hasDelta = deltaReady && delta?.hasComparison == true;
    final statsUsable = statsReady && deltaReady;
    final allowedRatio = hasDelta
        ? gaugeFillFromDelta(delta!.allowedPercent)
        : (statsUsable ? stats.dayAllowedRatio : 0.0);
    final blockedRatio = hasDelta
        ? gaugeFillFromDelta(delta!.blockedPercent)
        : (statsUsable ? stats.dayBlockedRatio : 0.0);
    final allowedVal = min(max(allowedRatio, 0.0), 100.0);
    final blockedVal = min(max(blockedRatio, 0.0), 100.0);

    allowedData = _ChartData(
      RadialRing.allowed,
      "stats label allowed".i18n,
      allowedVal,
      const Color(0xff33c75a),
    );

    blockedData = _ChartData(
      RadialRing.blocked,
      "stats label blocked".i18n,
      blockedVal,
      const Color(0xffff3b30),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ringSelection = selectedRing;
    final allowedOpacity =
        ringSelection == null || ringSelection == RadialRing.allowed ? 1.0 : 0.35;
    final blockedOpacity =
        ringSelection == null || ringSelection == RadialRing.blocked ? 1.0 : 0.35;

    // Derive ring sizes from pixel targets but express as percents (Syncfusion expects %)
    const blockedOuterRadiusPct = 92.0;
    const targetThicknessPx = 12.0;
    const targetGapPx = 3.0;
    const selectedOffsetPct = 3.0;
    const hitSlop = 6.0;

    String radiusPercent(double value) => '${value.toStringAsFixed(1)}%';

    double pxToPercent(double px, double maxRadius) =>
        (px / maxRadius * 100).clamp(0, 100);

    String radiusFor(RadialRing ring, double basePct) {
      if (ringSelection == ring) {
        return radiusPercent(min(basePct + selectedOffsetPct, 100));
      }
      return radiusPercent(max(basePct, 0));
    }

    RadialRing? hitTestRing(Offset localPosition, Size size) {
      final center = Offset(size.width / 2, size.height / 2);
      final distance = (localPosition - center).distance;
      final maxRadius = min(size.width, size.height) / 2;
      final thicknessPct = pxToPercent(targetThicknessPx, maxRadius);
      final gapPct = pxToPercent(targetGapPx, maxRadius);
      final blockedInnerPct = blockedOuterRadiusPct - thicknessPct;
      final allowedOuterPct = blockedInnerPct - gapPct;
      final allowedThicknessPct =
          thicknessPct * (allowedOuterPct / blockedOuterRadiusPct).clamp(0.0, 1.0);
      final allowedInnerPct = allowedOuterPct - allowedThicknessPct;

      final blockedOuter = maxRadius * (blockedOuterRadiusPct / 100);
      final blockedInner = maxRadius * (blockedInnerPct / 100);
      final allowedOuter = maxRadius * (allowedOuterPct / 100);
      final allowedInner = maxRadius * (allowedInnerPct / 100);

      if (distance >= blockedInner - hitSlop && distance <= blockedOuter + hitSlop) {
        return RadialRing.blocked;
      }
      if (distance >= allowedInner - hitSlop && distance <= allowedOuter + hitSlop) {
        return RadialRing.allowed;
      }
      return null;
    }

    Shader ringShader(RadialRing ring, Rect rect) {
      final colors = ring == RadialRing.allowed ? colorsGreen : colorsRed;
      return ui.Gradient.radial(
        rect.center,
        rect.width / 2,
        colors,
        stops,
        TileMode.clamp,
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final maxRadius = min(size.width, size.height) / 2;
      final thicknessPct = pxToPercent(targetThicknessPx, maxRadius);
      final gapPct = pxToPercent(targetGapPx, maxRadius);
      final blockedInnerPct = blockedOuterRadiusPct - thicknessPct;
      final allowedOuterPct = blockedInnerPct - gapPct;
      final allowedThicknessPct =
          thicknessPct * (allowedOuterPct / blockedOuterRadiusPct).clamp(0.0, 1.0);
      final allowedInnerPct = allowedOuterPct - allowedThicknessPct;

      return Stack(
        fit: StackFit.expand,
        children: [
          SfCircularChart(series: <CircularSeries>[
          // Renders radial bar chart
          RadialBarSeries<_ChartData, String>(
            dataSource: [blockedData],
            maximumValue: 100,
            xValueMapper: (_ChartData data, _) => data.x,
            yValueMapper: (_ChartData data, _) => data.y,
            pointColorMapper: (_ChartData data, _) => data.color,
            pointShaderMapper: (dynamic data, _, Color color, Rect rect) =>
                ringShader((data as _ChartData).ring, rect),
            cornerStyle: CornerStyle.bothFlat,
            useSeriesColor: true,
            trackOpacity: 0.1,
            gap: '3%',
            innerRadius: radiusFor(RadialRing.blocked, blockedInnerPct),
            radius: radiusFor(RadialRing.blocked, blockedOuterRadiusPct),
            animationDuration: 1200,
            opacity: blockedOpacity,
          ),
          RadialBarSeries<_ChartData, String>(
            dataSource: [allowedData],
            maximumValue: 100,
            xValueMapper: (_ChartData data, _) => data.x,
            yValueMapper: (_ChartData data, _) => data.y,
            pointColorMapper: (_ChartData data, _) => data.color,
            pointShaderMapper: (dynamic data, _, Color color, Rect rect) =>
                ringShader((data as _ChartData).ring, rect),
            cornerStyle: CornerStyle.bothFlat,
            useSeriesColor: true,
            trackOpacity: 0.1,
            gap: '3%',
            innerRadius: radiusFor(RadialRing.allowed, allowedInnerPct),
            radius: radiusFor(RadialRing.allowed, allowedOuterPct),
            animationDuration: 1200,
            opacity: allowedOpacity,
          ),
        ]),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              if (onRingTap == null) return;
              final ring = hitTestRing(details.localPosition, size);
              if (ring != null) {
                onRingTap!(ring);
              }
            },
          ),
        ),
      ],
    );
    });
  }
}

// Convert degree to radian
double _degreeToRadian(int deg) => deg * (3.141592653589793 / 180);

// Rotate the sweep gradient according to the start angle
Float64List _resolveTransform(Rect bounds, TextDirection textDirection) {
  final GradientTransform transform = GradientRotation(_degreeToRadian(-90));
  return transform.transform(bounds, textDirection: textDirection)!.storage;
}

class _ChartData {
  _ChartData(this.ring, this.x, this.y, this.color);

  final RadialRing ring;
  final String x;
  final double y;
  final Color color;
}
