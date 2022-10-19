import 'dart:async';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'dart:ui' as ui;
import 'dart:math' as math;

import '../main.dart';
import '../model/AppModel.dart';
import '../repo/AppRepo.dart';
import '../repo/Repos.dart';
import '../repo/StatsRepo.dart';

class PowerButton extends StatefulWidget {

  PowerButton({
    Key? key
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PowerButtonState();
  }

}

class _PowerButtonState extends State<PowerButton> with TickerProviderStateMixin {

  AppModel appModel = AppModel.empty();

  late AppRepo appRepo = Repos.instance.app;
  late StatsRepo statsRepo = Repos.instance.stats;

  late Future<List<ui.Image>> loadIcons;

  late AnimationController animCtrlLoading;
  late AnimationController animCtrlLibre;
  late AnimationController animCtrlPlus;
  late AnimationController animCtrlCover;
  late AnimationController animCtrlArcAlpha;
  late AnimationController animCtrlArcStart;
  late AnimationController animCtrlArcCounter;
  late AnimationController animCtrlArc2Counter;

  late Animation<double> animLoading;
  late Animation<double> animLibre;
  late Animation<double> animPlus;
  late Animation<double> animCover;
  late Animation<double> animArcAlpha;
  late Animation<double> animArcLoading;
  late Animation<double> animArcCounter;
  late Animation<double> animArc2Counter;

  bool pressed = false;

  var loadingCounter = 0.5;
  var counter = 0.3;
  var newCounter = 0.5;

  @override
  void initState() {
    super.initState();
    loadIcons = _loadIcons(["assets/images/ic_power.png", "assets/images/ic_pause.png"]);

    animCtrlLibre = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    animLibre = Tween<double>(begin: 0, end: 1).animate(animCtrlLibre)
      ..addListener(() {
        setState(() {});
      });

    animCtrlPlus = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    animPlus = Tween<double>(begin: 0, end: 1).animate(animCtrlPlus)
      ..addListener(() {
        setState(() {});
      });

    animCtrlCover = AnimationController(vsync: this, duration: Duration(milliseconds: 200));
    animCover = Tween<double>(begin: 1, end: 0).animate(animCtrlCover)
      ..addListener(() {
        setState(() {});
      });

    animCtrlArcStart = AnimationController(vsync: this, duration: Duration(milliseconds: 2000));
    animArcLoading = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: animCtrlArcStart, curve: Curves.ease))
      ..addListener(() {
        setState(() {});
      });

    animCtrlArcCounter = AnimationController(vsync: this, duration: Duration(milliseconds: 1500));
    animArcCounter = Tween<double>(begin: counter, end: newCounter).animate(animCtrlArcCounter)
      ..addListener(() {
        setState(() {});
      });

    animCtrlArcAlpha = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    animArcAlpha = Tween<double>(begin: 0.0, end: 1.0).animate(animCtrlArcAlpha)
      ..addListener(() {
        setState(() {});
      });

    animCtrlArc2Counter = AnimationController(vsync: this, duration: Duration(milliseconds: 1500));
    animCtrlArc2Counter.reverseDuration = Duration(milliseconds: 500);
    animArc2Counter = Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: animCtrlArc2Counter, curve: Curves.easeOutQuad))
      ..addListener(() {
        setState(() {});
      });

    animCtrlLoading = AnimationController(vsync: this, duration: Duration(milliseconds: 2000),);
    animLoading = Tween<double>(begin: 0, end: 1).animate(animCtrlLoading)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          // Once the loading spinning is stopped, signal it to other parts of the UI
          // This is when the "counter count up" animation should start
          if (appModel.state == AppState.activated) {
            appRepo.powerOnIsReady();
          }
        }
      });

    mobx.autorun((_) {
      var s = appRepo.appState;
      appModel = s;
      pressed = (s.state == AppState.activated && !s.working) || (s.state != AppState.activated && s.working);
      // A bit of a hack to make sure the flag is flagged
      if (s.state == AppState.activated && !s.working && !appRepo.powerOnAnimationReady && animLoading.isDismissed) {
        appRepo.powerOnIsReady();
      }
      _scheduleUpdateAnimations();
    });

    mobx.autorun((_) {
      if (appRepo.powerOnAnimationReady && !appModel.working && appModel.state == AppState.activated && statsRepo.hasStats) {
        // Max is 2.0 so that it can display ring overlap
        newCounter = math.min(2.0, statsRepo.stats.dayAllowedRatio / 100);

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

  _scheduleUpdateAnimations() {
    timer ??= Timer(Duration(milliseconds: 200), () {
      _updateAnimations();
      timer = null;
    });
  }

  _updateAnimations() {
    if (appModel.working) {
      _animateStatusRingTo(loadingCounter);

      animCtrlLoading.forward();
      animCtrlArcStart.repeat();
      animCtrlArcAlpha.forward();
      animCtrlArc2Counter.reverse();
    } else {
      animCtrlLoading.reverse();
      if (appModel.state == AppState.paused || appModel.state == AppState.deactivated) {
        animCtrlArcAlpha.reverse();
      } else {
        animCtrlArcAlpha.forward();
      }
    }

    if (appModel.state == AppState.activated) {
      animCtrlLibre.forward();
      if (appModel.plus) {
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
  }

  _animateStatusRingTo(double value) {
    if (value == counter) {
      // Assume we are already animating to this value, ignore
      return;
    }

    print("Animating status ring from ${animArcCounter.value} to $value, isAnimating: ${animCtrlArcCounter.isAnimating}");
    animArcCounter = Tween<double>(begin: animArcCounter.value, end: value)
        .animate(CurvedAnimation(parent: animCtrlArcCounter, curve: Curves.easeOutQuad))
      ..addListener(() {
        setState(() {});
      });
    counter = value;
    animCtrlArcCounter.reset();
    animCtrlArcCounter.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BrandTheme>()!;

    return Column(
        children: [
          SizedBox(
            width: 210,
            height: 210,
            child: GestureDetector(
              onTap: () {
                if (!appModel.working) {
                  setState(() {
                    appRepo.pressedPowerButton();
                    _updateAnimations();
                  });
                }
              },
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
                          animation: Listenable.merge([animLoading, animLibre, animPlus, animCover, animArcLoading, animArcCounter, animArcAlpha, animArc2Counter]),
                          builder: (BuildContext context, Widget? child) {
                            return CustomPaint(
                              painter: PowerButtonPainter(
                                iconImage: (appModel.state == AppState.paused) ? snapshot.data![1] : snapshot.data![0],
                                alphaLoading: animLoading.value,
                                alphaCover: animCover.value,
                                alphaLibre: animLibre.value,
                                alphaPlus: animPlus.value,
                                arcAlpha: animArcAlpha.value,
                                arcStart: animArcLoading.value,
                                arcEnd: animArcCounter.value,
                                arcCounter: [
                                  animArc2Counter.value * math.min(2.0, (statsRepo.stats.dayBlockedRatio / 100)),
                                  0,
                                  0
                                ],
                                colorShadow: theme.shadow
                              ),
                            );
                          },
                        );
                      }
                  }
                },
              )
            ),
          ),
        ]
    );
  }

  @override
  void dispose() {
    animCtrlLoading.dispose();
    animCtrlLoading.dispose();
    animCtrlLibre.dispose();
    animCtrlPlus.dispose();
    animCtrlCover.dispose();
    animCtrlArcAlpha.dispose();
    animCtrlLoading.dispose();
    animCtrlArcCounter.dispose();
    animCtrlArc2Counter.dispose();
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
  final ringWith = 6.0;
  final iconWidth = 160.0;
  final blurRadius = 5.0;

  final alphaLibre;
  final alphaLoading;
  final alphaCover;
  final alphaPlus;
  final arcStart;
  final double arcEnd;
  final arcAlpha;
  final List<double> arcCounter;
  final Color colorShadow;

  late Color colorCover1 = Colors.white.withOpacity(alphaCover);
  late Color colorCover2 = Colors.white.withOpacity(alphaCover);
  late Color colorRingLibre1 = Color(0xFF007AFF).withOpacity(alphaLibre);
  late Color colorRingLibre2 = Color(0xFF5856D5).withOpacity(alphaLibre);
  late Color colorRingPlus1 = Color(0xFFFF9400).withOpacity(alphaPlus);
  late Color colorRingPlus2 = Color(0xFFEF6049).withOpacity(alphaPlus);
  late Color colorText = Colors.white;
  late Color colorLoading = Colors.white.withOpacity(alphaLoading);

  PowerButtonPainter({
    required this.iconImage,
    required this.alphaCover, required this.alphaPlus,
    required this.alphaLibre, required this.alphaLoading,
    required this.arcStart, required this.arcEnd, required this.arcAlpha,
    required this.arcCounter,
    required this.colorShadow
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
        ..strokeWidth = ringWith;

      Paint loadingRingPaint = Paint()
        ..color = colorLoading
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWith;

      Paint loadingArcPaint = Paint()
      ..color = Colors.white.withOpacity(math.min(arcAlpha, 0.4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWith * 0.5;

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
        ..strokeWidth = ringWith;

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
        ..strokeWidth = ringWith;

      Paint innerShadowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.5,
          stops: [0.0, 0.82, 0.88],
          colors: [
            colorShadow,
            colorShadow,
            Colors.black
          ],
        ).createShader(rect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

      // ring inactive
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - ringWith, inactiveRingPaint);

      // Filled background when active
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - edge * 1.5, innerShadowPaint);

      // ring blue
      //libreRingPaint.alpha = alphaBlue
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - ringWith, libreRingPaint);

      // ring orange
      // plusRingPaint.alpha = alphaOrange
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - ringWith, plusRingPaint);

      // ring loading
      // loadingRingPaint.alpha = alphaLoading
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - ringWith, loadingRingPaint);

      // shadow and the off state cover
      // shadowPaint.alpha = alphaCover
      // offButtonPaint.alpha = alphaCover
      //canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - edge * 0.5, shadowPaint);
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - edge * 1.7, coverPaint);

      // loading arc and blocked counter
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 1, - ringWith * 1, size.width + ringWith * 2, size.height + ringWith * 2),
          arcStart * math.pi * 2 - math.pi / 2, math.min(arcEnd, 1.0) * math.pi * 2, false, loadingArcPaint);

      // counter arc total
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 2, - ringWith * 2, size.width + ringWith * 4, size.height + ringWith * 4),
          0 - math.pi / 2, math.min(arcCounter[0], 1.0) * math.pi * 2, false, loadingArcPaint);

      // blocked counter - the overlap
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 1, - ringWith * 1, size.width + ringWith * 2, size.height + ringWith * 2),
          0 - math.pi / 2, math.max(0, arcEnd - 1.0) * math.pi * 2, false, loadingArcPaint);

      // counter arc total - the overlap
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 2, - ringWith * 2, size.width + ringWith * 4, size.height + ringWith * 4),
          0 - math.pi / 2, math.max(0, arcCounter[0] - 1.0) * math.pi * 2, false, loadingArcPaint);

      // counter arc 10k-100k unused
      // canvas.drawArc(
      //     Rect.fromLTWH(- ringWith * 3, - ringWith * 3, size.width + ringWith * 6, size.height + ringWith * 6),
      //     0 - math.pi / 2, arcCounter[1] * math.pi * 2, false, loadingArcPaint);
      //
      // // counter arc 100k-1m unused
      // canvas.drawArc(
      //     Rect.fromLTWH(- ringWith * 4, - ringWith * 4, size.width + ringWith * 8, size.height + ringWith * 8),
      //     0 - math.pi / 2, arcCounter[2] * math.pi * 2, false, loadingArcPaint);

      // draw icon
      final iconColor = (alphaPlus == 1.0) ? colorRingPlus1 :
      ((alphaLibre == 1.0) ? colorRingLibre1 :
      ((alphaCover > 0.0) ? Colors.black :
      ((colorShadow.isLight) ? Colors.black :
      Colors.white)));

      Paint iconPaint = Paint()
        //..colorFilter = ColorFilter.mode(colorRingPlus1, BlendMode.srcIn);
        ..isAntiAlias = true
        ..colorFilter = ColorFilter.mode(iconColor, BlendMode.srcIn);

      canvas.drawImage(iconImage,
          Offset(size.width / 2 - iconImage.width / 2, size.height / 2 - iconImage.height / 2),
          iconPaint);
    }

    @override
    bool shouldRepaint(CustomPainter oldDelegate) {
      return true;
    }

}