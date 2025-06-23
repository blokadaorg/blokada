import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:common/common/action_sheet.dart';
import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/touch.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/app/channel.pg.dart';
import 'package:common/platform/app/start/start.dart';
import 'package:common/platform/stats/stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:relative_scale/relative_scale.dart';

import 'home.dart';

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
  late final _home = Core.get<HomeStore>();
  late final _modal = Core.get<CurrentModalValue>();

  late Future<List<ui.Image>> loadIcons;

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

  bool pressed = false;

  var loadingCounter = 0.5;
  var counter = 0.3;
  var newCounter = 0.5;

  int? pausedForSeconds;
  Timer? timerRefresh;

  @override
  void initState() {
    super.initState();
    loadIcons = _loadIcons(["assets/images/ic_power.png", "assets/images/ic_pause.png"]);

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

    animCtrlLoading = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );
    animLoading = Tween<double>(begin: 0, end: 1).animate(animCtrlLoading)
      ..addListener(() {
        _setState();
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          // Once the loading spinning is stopped, signal it to other parts of the UI
          // This is when the "counter count up" animation should start
          final status = _app.status;
          //log(m).i("loading animation dismissed");
          if (status.isActive()) {
            log(Markers.root).i("loading animation dismissed, power on is ready");
            _home.powerOnIsReady();
          }
        }
      });

    mobx.autorun((_) {
      final s = _app.status;
      pressed = (s.isActive()) || (s.isWorking());
      // A bit of a hack to make sure the flag is flagged
      //log(m).i("app status changed");
      if (s.isActive() && !_home.powerOnAnimationReady && animLoading.isDismissed) {
        _home.powerOnIsReady();
        log(Markers.root).i("app status active, power on is ready");
      }
      pausedForSeconds = _appStart.pausedForAccurate?.inSeconds;
      _scheduleUpdateAnimations();
      _scheduleTimerRefresh();
    });

    mobx.autorun((_) {
      final s = _app.status;
      final hasStats = _stats.hasStats;
      final stats = _stats.stats;

      //log(m).i("another callback triggerred");
      if (_home.powerOnAnimationReady && s.isActive() && hasStats) {
        //log(m).i("moving loading ring on pos to display the active anim");
        // Max is 2.0 so that it can display ring overlap
        newCounter = math.min(2.0, stats.dayAllowedRatio / 100);

        // A hack to move the loading spinner to the position 0 and animate stats counter instead
        animCtrlArcStart.animateTo(0.999);

        _animateStatusRingTo(newCounter);
        //animCtrlArc2Counter.reset();
        animCtrlArc2Counter.forward();
      }
    });

    _scheduleUpdateAnimations();
  }

  Timer? timer;

  _setState() {
    if (mounted) {
      setState(() {});
    }
  }

  _scheduleUpdateAnimations() {
    timer ??= Timer(const Duration(milliseconds: 200), () {
      _updateAnimations();
      timer = null;
    });
  }

  _scheduleTimerRefresh() {
    timerRefresh?.cancel();
    if (_getRemainingSeconds() > 0) {
      timerRefresh = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_getRemainingSeconds() > 0) {
          _setState();
        } else {
          timer.cancel();
          timerRefresh = null;
        }
      });
    }
  }

  _updateAnimations() {
    final status = _app.status;
    if (status.isWorking()) {
      _animateStatusRingTo(loadingCounter);

      animCtrlLoading.forward();
      animCtrlArcStart.repeat();
      animCtrlArcAlpha.forward();
      animCtrlArc2Counter.reverse();
    } else {
      animCtrlLoading.reverse();
      if (status.isInactive()) {
        animCtrlArcAlpha.reverse();
      } else {
        //log(m).i("not working, but active, change arc alpha");
        animCtrlArcAlpha.forward();
      }
    }

    if (status.isActive()) {
      animCtrlLibre.forward();
      if (status == AppStatus.activatedPlus) {
        animCtrlPlus.forward();
      } else {
        animCtrlPlus.reverse();
      }
    } else {
      animCtrlLibre.reverse();
      animCtrlPlus.reverse();
    }

    if (pressed) {
      animCtrlCover.forward();
    } else {
      animCtrlCover.reverse();
    }

    if (pausedForSeconds != null) {
      // If the app is paused, animate the timer arc
      animCtrlArcTimerCounter.value = 1 - (pausedForSeconds! / 300.0);
      animCtrlArcTimerCounter.forward();
    } else {
      // If the app is not paused, reset the timer arc (to end animation value)
      animCtrlArcTimerCounter.value = 1.0;
    }
  }

  _animateStatusRingTo(double value) {
    if (value == counter) {
      // Assume we are already animating to this value, ignore
      return;
    }

    //log.v("Animating status ring from ${animArcCounter.value} to $value, isAnimating: ${animCtrlArcCounter.isAnimating}");
    animArcCounter = Tween<double>(begin: animArcCounter.value, end: value)
        .animate(CurvedAnimation(parent: animCtrlArcCounter, curve: Curves.easeOutQuad))
      ..addListener(() {
        _setState();
      });
    counter = value;
    animCtrlArcCounter.reset();
    animCtrlArcCounter.forward();
  }

  @override
  Widget build(BuildContext context) {
    final status = _app.status;
    final stats = _stats.stats;
    final theme = Theme.of(context).extension<BlokadaTheme>()!;

    return RelativeBuilder(builder: (context, height, width, sy, sx) {
      final buttonSize = math.min(sy(140), 180.0);
      return Stack(
        children: [
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: FutureBuilder<List<ui.Image>>(
              future: loadIcons,
              builder: (BuildContext context, AsyncSnapshot<List<ui.Image>> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return const CircularProgressIndicator();
                  default:
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    } else {
                      return AnimatedBuilder(
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
                                iconImage: (status == AppStatus.paused)
                                    ? snapshot.data![1]
                                    : snapshot.data![0],
                                alphaLoading: animLoading.value,
                                alphaCover: animCover.value,
                                alphaLibre: animLibre.value,
                                alphaPlus: animPlus.value,
                                arcAlpha: animArcAlpha.value,
                                arcStart: animArcLoading.value,
                                arcEnd: animArcCounter.value,
                                arcTimerEnd: animArcTimerCounter.value,
                                arcCounter: [
                                  animArc2Counter.value *
                                      math.min(2.0, (stats.dayBlockedRatio / 100)),
                                  0,
                                  0
                                ],
                                colorShadow: theme.shadow),
                          );
                        },
                      );
                    }
                }
              },
            ),
          ),
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: Touch(
              onTap: () {
                if (!status.isWorking()) {
                  setState(() {
                    log(Markers.userTap).trace("tappedPowerButton", (m) async {
                      if (!status.isActive()) {
                        try {
                          await _appStart.toggleApp(m);
                        } on OnboardingException catch (_) {
                          _modal.change(Markers.userTap, Modal.onboardPrivateDns);
                        }
                      } else {
                        showPauseActionSheet(context, onSelected: (duration) {
                          log(Markers.userTap).trace("tappedPowerButtonDialog", (m) async {
                            _appStart.toggleApp(m, duration: duration);
                          });
                        });
                      }
                    });
                    pausedForSeconds = null;
                    _updateAnimations();
                  });
                }
              },
              onLongTap: () {
                if (!status.isWorking()) {
                  setState(() {
                    log(Markers.userTap).trace("tappedPowerButtonLong", (m) async {
                      try {
                        await _appStart.toggleApp(m);
                      } on OnboardingException catch (_) {
                        _modal.change(Markers.userTap, Modal.onboardPrivateDns);
                      }
                    });
                    pausedForSeconds = null;
                    _updateAnimations();
                  });
                }
              },
              maxValue: 0.5,
              decorationBuilder: (value) {
                return BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.shadow.withOpacity(value),
                );
              },
              child: Center(
                child: _getRemainingSeconds() > 0
                    ? Text(
                        _formatTime(_getRemainingSeconds()),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                          fontFamily: 'monospace',
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    : Icon(
                        Icons.power_settings_new_sharp,
                        size: 32,
                        color: (status.isInactive() ? Colors.black : theme.textPrimary)
                            .withOpacity(0.8),
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

  Future<List<ui.Image>> _loadIcons(List<String> paths) async {
    return await Future.wait(paths.map((path) async {
      var bytes = await rootBundle.load(path);
      return decodeImageFromList(bytes.buffer.asUint8List());
    }));
  }
}

class PowerButtonPainter extends CustomPainter {
  final ui.Image iconImage;

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

  late Color colorCover1 = Colors.white.withOpacity(alphaCover);
  late Color colorCover2 = Colors.white.withOpacity(alphaCover);
  late Color colorRingLibre1 = Color(0xFF007AFF).withOpacity(alphaLibre);
  late Color colorRingLibre2 = Color(0xFF5856D5).withOpacity(alphaLibre);
  late Color colorRingPlus1 = Color(0xFFFF9400).withOpacity(alphaPlus);
  late Color colorRingPlus2 = Color(0xFFEF6049).withOpacity(alphaPlus);
  late Color colorText = Colors.white;
  late Color colorLoading = Colors.white.withOpacity(alphaLoading);
  late Color colorTimer = colorShadow;

  PowerButtonPainter({
    required this.iconImage,
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
