import 'dart:async';
import 'dart:math' as math;

import 'package:common/src/shared/ui/action_sheet.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/features/home/domain/power.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/shared/ui/touch.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/start/start.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:relative_scale/relative_scale.dart';

/// The Home power button. What it shows and what a tap does come from
/// [powerButtonState]; the widget only draws and animates that state.
class PowerButton extends StatefulWidget {
  PowerButton({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PowerButtonState();
  }
}

class _PowerButtonState extends State<PowerButton> with TickerProviderStateMixin, Logging {
  late final _app = Core.get<AppStore>();
  late final _appStart = Core.get<AppStartStore>();
  late final _stats = Core.get<StatsStore>();
  late final _account = Core.get<AccountStore>();
  late final _power = Core.get<PowerActor>();

  late AnimationController animCtrlLoading;
  late AnimationController animCtrlLibre;
  late AnimationController animCtrlPlus;
  late AnimationController animCtrlCover;
  late AnimationController animCtrlArcAlpha;
  late AnimationController animCtrlArcStart;
  late AnimationController animCtrlArcCounter;
  late AnimationController animCtrlArc2Counter;
  late AnimationController animCtrlArcTimerCounter;

  late Animation<double> animLoading;
  late Animation<double> animLibre;
  late Animation<double> animPlus;
  late Animation<double> animCover;
  late Animation<double> animArcAlpha;
  late Animation<double> animArcLoading;
  late Animation<double> animArcCounter;
  late Animation<double> animArc2Counter;
  late Animation<double> animArcTimerCounter;

  final _reactions = <mobx.ReactionDisposer>[];

  // The stats rings take over from the spinner only once it has faded out
  // with protection on; switching off or reconnecting hides them again.
  bool _statsRingsShown = false;

  var loadingCounter = 0.5;
  var counter = 0.3;
  var newCounter = 0.5;

  Timer? timerRefresh;

  PowerButtonState get _state => powerButtonState(
        status: _app.status,
        isFreemium: _account.isFreemium,
        pauseSecondsLeft: _getRemainingSeconds(),
      );

  @override
  void initState() {
    super.initState();

    animCtrlLibre = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    animLibre = Tween<double>(begin: 0, end: 1).animate(animCtrlLibre)
      ..addListener(() {
        _setState();
      });

    animCtrlPlus = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    animPlus = Tween<double>(begin: 0, end: 1).animate(animCtrlPlus)
      ..addListener(() {
        _setState();
      });

    animCtrlCover = AnimationController(vsync: this, duration: Duration(milliseconds: 200));
    animCover = Tween<double>(begin: 1, end: 0).animate(animCtrlCover)
      ..addListener(() {
        _setState();
      });

    animCtrlArcStart = AnimationController(vsync: this, duration: Duration(milliseconds: 2000));
    animArcLoading = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: animCtrlArcStart, curve: Curves.ease))
      ..addListener(() {
        _setState();
      });

    animCtrlArcCounter = AnimationController(vsync: this, duration: Duration(milliseconds: 1500));
    animArcCounter = Tween<double>(begin: counter, end: newCounter).animate(animCtrlArcCounter)
      ..addListener(() {
        _setState();
      });

    animCtrlArcAlpha = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    animArcAlpha = Tween<double>(begin: 0.0, end: 1.0).animate(animCtrlArcAlpha)
      ..addListener(() {
        _setState();
      });

    animCtrlArc2Counter = AnimationController(vsync: this, duration: Duration(milliseconds: 1500));
    animCtrlArc2Counter.reverseDuration = Duration(milliseconds: 500);
    animArc2Counter = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: animCtrlArc2Counter, curve: Curves.easeOutQuad))
      ..addListener(() {
        _setState();
      });

    // Use 5 min as this is our default pause time
    animCtrlArcTimerCounter =
        AnimationController(vsync: this, duration: const Duration(minutes: 5));
    animArcTimerCounter = Tween<double>(begin: 1, end: 0).animate(animCtrlArcTimerCounter)
      ..addListener(() {
        _setState();
      });
    animCtrlArcTimerCounter.value = _state.pauseArc;

    animCtrlLoading = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );
    animLoading = Tween<double>(begin: 0, end: 1).animate(animCtrlLoading)
      ..addListener(() {
        _setState();
      })
      ..addStatusListener((status) {
        // The spinner has faded out: the stats rings count up in its place.
        if (status == AnimationStatus.dismissed && _app.status.isActive()) {
          _showStatsRings();
        }
      });

    _reactions.add(mobx.autorun((_) {
      final s = _app.status;
      if (!s.isActive()) {
        _statsRingsShown = false;
      } else if (animLoading.isDismissed) {
        // No spinner to wait for (protection was already on at start).
        _showStatsRings();
      }
      _scheduleUpdateAnimations();
      _scheduleTimerRefresh();
    }));

    _reactions.add(mobx.autorun((_) {
      // Read here so the reaction tracks them.
      _app.status;
      _stats.hasStats;
      _stats.stats;
      _updateStatsRings();
    }));

    _scheduleUpdateAnimations();
  }

  Timer? timer;

  _setState() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showStatsRings() {
    if (_statsRingsShown) return;
    _statsRingsShown = true;
    // Untracked: the status reaction calling this must not also react to stats.
    mobx.untracked(_updateStatsRings);
  }

  void _updateStatsRings() {
    final stats = _stats.stats;
    if (!_statsRingsShown || !_app.status.isActive() || !_stats.hasStats) return;

    // Max is 2.0 so that it can display ring overlap
    newCounter = math.min(2.0, stats.dayAllowedRatio / 100);

    // Park the loading arc at the top so the stats arcs replace it
    animCtrlArcStart.animateTo(0.999);

    _animateStatusRingTo(newCounter);
    animCtrlArc2Counter.forward();
  }

  _scheduleUpdateAnimations() {
    timer ??= Timer(const Duration(milliseconds: 200), () {
      _updateAnimations();
      timer = null;
    });
  }

  _scheduleTimerRefresh() {
    timerRefresh?.cancel();
    if (_state.pauseSecondsLeft != null) {
      timerRefresh = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_state.pauseSecondsLeft != null) {
          _setState();
        } else {
          timer.cancel();
          timerRefresh = null;
        }
      });
    }
  }

  _updateAnimations() {
    final state = _state;
    if (state.working) {
      _animateStatusRingTo(loadingCounter);

      animCtrlLoading.forward();
      animCtrlArcStart.repeat();
      animCtrlArcAlpha.forward();
      animCtrlArc2Counter.reverse();
    } else {
      animCtrlLoading.reverse();
      if (state.inactive) {
        animCtrlArcAlpha.reverse();
      } else {
        animCtrlArcAlpha.forward();
      }
    }

    if (state.active) {
      animCtrlLibre.forward();
      if (state.plus) {
        animCtrlPlus.forward();
      } else {
        animCtrlPlus.reverse();
      }
    } else {
      animCtrlLibre.reverse();
      animCtrlPlus.reverse();
    }

    if (state.pressed) {
      animCtrlCover.forward();
    } else {
      animCtrlCover.reverse();
    }

    if (state.pauseSecondsLeft != null) {
      // If the app is paused, animate the timer arc
      animCtrlArcTimerCounter.value = state.pauseArc;
      animCtrlArcTimerCounter.forward();
    } else {
      // Hide the timer arc when there is no actual pause timer.
      animCtrlArcTimerCounter.stop();
      animCtrlArcTimerCounter.value = 1.0;
    }
  }

  _animateStatusRingTo(double value) {
    if (value == counter) {
      // Assume we are already animating to this value, ignore
      return;
    }

    animArcCounter = Tween<double>(begin: animArcCounter.value, end: value)
        .animate(CurvedAnimation(parent: animCtrlArcCounter, curve: Curves.easeOutQuad))
      ..addListener(() {
        _setState();
      });
    counter = value;
    animCtrlArcCounter.reset();
    animCtrlArcCounter.forward();
  }

  void _onTap(PowerTap tap) {
    switch (tap) {
      case PowerTap.none:
        return;
      case PowerTap.toggle:
        unawaited(_power.toggle(Markers.userTap));
      case PowerTap.pauseSheet:
        showPauseActionSheet(context, onSelected: (duration) {
          unawaited(_power.pause(Markers.userTap, duration));
        });
    }
    // Toggling can switch the status synchronously; start the spinner now
    // rather than after the scheduled update.
    _updateAnimations();
    _setState();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final stats = _stats.stats;
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    final pauseSecondsLeft = state.pauseSecondsLeft;

    return RelativeBuilder(builder: (context, height, width, sy, sx) {
      final buttonSize = math.min(sy(140), 180.0);
      return Stack(
        children: [
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                animLoading,
                animLibre,
                animPlus,
                animCover,
                animArcLoading,
                animArcCounter,
                animArcAlpha,
                animArc2Counter,
                animArcTimerCounter,
              ]),
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: PowerButtonPainter(
                    alphaLoading: animLoading.value,
                    alphaCover: animCover.value,
                    alphaLibre: animLibre.value,
                    alphaPlus: animPlus.value,
                    arcAlpha: animArcAlpha.value,
                    arcStart: animArcLoading.value,
                    arcEnd: animArcCounter.value,
                    arcTimerEnd: animArcTimerCounter.value,
                    arcCounter: [
                      animArc2Counter.value * math.min(2.0, (stats.dayBlockedRatio / 100)),
                      0,
                      0
                    ],
                    colorShadow: theme.shadow,
                    isFreemium: state.freemium,
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: Semantics(
              identifier: AutomationIds.powerToggle,
              button: true,
              label: "home power button label".i18n,
              // The value stays untranslated for the Appium flows; screen
              // readers get the translated state from the hint.
              value: state.active ? 'active' : 'inactive',
              hint: state.active
                  ? "home power button state on".i18n
                  : "home power button state off".i18n,
              child: Touch(
                onTap: () => _onTap(state.tap),
                onLongTap: () => _onTap(state.longTap),
                maxValue: 0.5,
                decorationBuilder: (value) {
                  return BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.shadow.withOpacity(value),
                  );
                },
                child: Center(
                  child: pauseSecondsLeft != null
                      ? Text(
                          _formatTime(pauseSecondsLeft),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'monospace',
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        )
                      : Icon(
                          Icons.power_settings_new_sharp,
                          size: 32,
                          color: (state.inactive ? Colors.black : theme.textPrimary)
                              .withOpacity(0.8),
                        ),
                ),
              ),
            ),
          )
        ],
      );
    });
  }

  int _getRemainingSeconds() {
    final pausedUntil = _appStart.pausedUntil;
    if (pausedUntil == null) return 0;
    final remaining = pausedUntil.difference(DateTime.now());
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    for (final dispose in _reactions) {
      dispose();
    }
    _reactions.clear();
    timer?.cancel();
    timerRefresh?.cancel();
    animCtrlLoading.stop();
    animCtrlLoading.dispose();
    animCtrlLibre.stop();
    animCtrlLibre.dispose();
    animCtrlPlus.stop();
    animCtrlPlus.dispose();
    animCtrlCover.stop();
    animCtrlCover.dispose();
    animCtrlArcAlpha.stop();
    animCtrlArcAlpha.dispose();
    animCtrlArcStart.stop();
    animCtrlArcStart.dispose();
    animCtrlArcCounter.stop();
    animCtrlArcCounter.dispose();
    animCtrlArc2Counter.stop();
    animCtrlArc2Counter.dispose();
    animCtrlArcTimerCounter.stop();
    animCtrlArcTimerCounter.dispose();
    super.dispose();
  }
}

class PowerButtonPainter extends CustomPainter {
  final edge = 9.0;
  final ringWidth = 6.0;
  final timerRingWidth = 12.0;
  final iconWidth = 30.0;
  final blurRadius = 5.0;

  final alphaLibre;
  final alphaLoading;
  final alphaCover;
  final alphaPlus;
  final arcStart;
  final double arcEnd;
  final arcAlpha;
  final List<double> arcCounter;
  final double arcTimerEnd;
  final Color colorShadow;
  final bool isFreemium;

  late Color colorCover1 = Colors.white.withOpacity(alphaCover);
  late Color colorCover2 = Colors.white.withOpacity(alphaCover);
  late Color colorRingLibre1 = Color(0xFF007AFF).withOpacity(alphaLibre);
  late Color colorRingLibre2 = Color(0xFF5856D5).withOpacity(alphaLibre);
  late Color colorRingPlus1 = Color(0xFFFF9400).withOpacity(alphaPlus);
  late Color colorRingPlus2 = Color(0xFFEF6049).withOpacity(alphaPlus);
  late Color colorLibreFreemium1 = Color(0xFFACBDBA).withOpacity(alphaLibre);
  late Color colorLibreFreemium2 = Color(0xFF48A9A6).withOpacity(alphaLibre);
  late Color colorText = Colors.white;
  late Color colorLoading = Colors.white.withOpacity(alphaLoading);
  late Color colorTimer = colorShadow;

  PowerButtonPainter({
    required this.alphaCover,
    required this.alphaPlus,
    required this.alphaLibre,
    required this.alphaLoading,
    required this.arcStart,
    required this.arcEnd,
    required this.arcAlpha,
    required this.arcCounter,
    required this.arcTimerEnd,
    required this.colorShadow,
    required this.isFreemium,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = Offset.zero & size;

    Paint coverPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colorCover1,
          colorCover2,
        ],
      ).createShader(rect);

    Paint inactiveRingPaint = Paint()
      ..color = colorShadow
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    Paint timerArcPaint = Paint()
      ..color = colorTimer.withOpacity(alphaCover)
      ..style = PaintingStyle.stroke
      ..strokeWidth = timerRingWidth;

    Paint loadingRingPaint = Paint()
      ..color = colorLoading
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    Paint loadingArcPaint = Paint()
      ..color = Colors.white.withOpacity(math.min(arcAlpha, 0.40))
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth * 0.5;

    Paint loadingArc2Paint = Paint()
      ..color = Colors.white.withOpacity(math.min(arcAlpha, 0.30))
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth * 0.5;

    Paint libreRingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          colorRingLibre1,
          colorRingLibre2,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    Paint freemiumRingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          colorLibreFreemium1,
          colorLibreFreemium2,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    Paint plusRingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          colorRingPlus1,
          colorRingPlus2,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    Paint innerShadowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        stops: [0.0, 0.82, 0.88],
        colors: [colorShadow, colorShadow, Colors.black],
      ).createShader(rect);
    // ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

    // ring inactive
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2 - ringWidth, inactiveRingPaint);

    // Filled background when active
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2 - edge * 1.5, innerShadowPaint);

    // ring blue
    //libreRingPaint.alpha = alphaBlue
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2 - ringWidth, libreRingPaint);

    if (isFreemium) {
      // ring freemium
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), size.width / 2 - ringWidth, freemiumRingPaint);
    }

    // ring orange
    // plusRingPaint.alpha = alphaOrange
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2 - ringWidth, plusRingPaint);

    // ring loading
    // loadingRingPaint.alpha = alphaLoading
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2 - ringWidth, loadingRingPaint);

    // shadow and the off state cover
    // shadowPaint.alpha = alphaCover
    // offButtonPaint.alpha = alphaCover
    //canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - edge * 0.5, shadowPaint);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2 - edge * 1.7, coverPaint);

    // timer arc (in ring place)
    drawDashedArc(
        canvas,
        Rect.fromLTWH(timerRingWidth * 2, timerRingWidth * 2, size.width - timerRingWidth * 4,
            size.height - timerRingWidth * 4),
        -math.pi / 2,
        -math.min(arcTimerEnd, 1.0) * math.pi * 2,
        timerArcPaint,
        0.05, // dash length in radians
        0.05 // gap length in radians
        );

    // loading arc and blocked counter
    canvas.drawArc(
        Rect.fromLTWH(-ringWidth * 1, -ringWidth * 1, size.width + ringWidth * 2,
            size.height + ringWidth * 2),
        arcStart * math.pi * 2 - math.pi / 2,
        math.min(arcEnd, 1.0) * math.pi * 2,
        false,
        loadingArcPaint);

    // counter arc total
    canvas.drawArc(
        Rect.fromLTWH(-ringWidth * 2, -ringWidth * 2, size.width + ringWidth * 4,
            size.height + ringWidth * 4),
        0 - math.pi / 2,
        math.min(arcCounter[0], 1.0) * math.pi * 2,
        false,
        loadingArcPaint);

    // blocked counter - the overlap
    canvas.drawArc(
        Rect.fromLTWH(-ringWidth * 1, -ringWidth * 1, size.width + ringWidth * 2,
            size.height + ringWidth * 2),
        0 - math.pi / 2,
        math.max(0, arcEnd - 1.0) * math.pi * 2,
        false,
        loadingArc2Paint);

    // counter arc total - the overlap
    canvas.drawArc(
        Rect.fromLTWH(-ringWidth * 2, -ringWidth * 2, size.width + ringWidth * 4,
            size.height + ringWidth * 4),
        0 - math.pi / 2,
        math.max(0, arcCounter[0] - 1.0) * math.pi * 2,
        false,
        loadingArc2Paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }

  // Draws a dashed arc on the canvas.
  void drawDashedArc(
    Canvas canvas,
    Rect rect,
    double startAngle,
    double sweepAngle,
    Paint paint,
    double dashLength,
    double gapLength,
  ) {
    double totalLength = sweepAngle.abs();
    double currentAngle = startAngle;
    final direction = sweepAngle.isNegative ? -1 : 1;

    while (totalLength > 0) {
      final currentDashLength = math.min(dashLength, totalLength);
      canvas.drawArc(
        rect,
        currentAngle,
        currentDashLength * direction,
        false,
        paint,
      );
      currentAngle += (currentDashLength + gapLength) * direction;
      totalLength -= (currentDashLength + gapLength);
    }
  }
}
