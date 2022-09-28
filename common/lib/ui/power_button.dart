import 'dart:async';

import 'package:countup/countup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
 import 'package:mobx/mobx.dart' as mobx;
import 'dart:ui' as ui;
import 'dart:math' as math;

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

  late Future<ui.Image> loadIcon;

  late AnimationController animCtrlLoading;
  late AnimationController animCtrlLibre;
  late AnimationController animCtrlPlus;
  late AnimationController animCtrlCover;
  late AnimationController animCtrlArcAlpha;
  late AnimationController animCtrlArcStart;
  late AnimationController animCtrlArcCounter;
  late AnimationController animCtrlMiniArcCounter;

  late Animation<double> animLoading;
  late Animation<double> animLibre;
  late Animation<double> animPlus;
  late Animation<double> animCover;
  late Animation<double> animArcAlpha;
  late Animation<double> animArcLoading;
  late Animation<double> animArcCounter;
  late Animation<double> animMiniArcCounter;

  bool pressed = false;

  var counter = 0.5;
  var newCounter = 0.5;
  var total = 0;
  var dayBlocked = 0.0;
  var lastDayBlocked = 0.0;

  @override
  void initState() {
    super.initState();
    loadIcon = _load("assets/images/ic_power.png");

    mobx.autorun((_) {
      total = statsRepo.stats.totalBlocked;
      //newCounter = math.min(1.0, (total % 1000) / 1000.0);
      //newCounter = math.min(1.0, statsRepo.stats.dayTotal / math.max(statsRepo.stats.avgDayTotal, 1.0));
      newCounter = 0.0;
      lastDayBlocked = dayBlocked;
      dayBlocked = statsRepo.stats.dayBlocked.toDouble();

      if (!animCtrlArcCounter.isAnimating) {
        animArcCounter = Tween<double>(begin: counter, end: newCounter)
          .animate(CurvedAnimation(parent: animCtrlArcCounter, curve: Curves.easeOutQuad))
          ..addListener(() {
            setState(() {});
          });
        counter = newCounter;
        animCtrlArcCounter.reset();
        animCtrlArcCounter.forward();
        //animCtrlMiniArcCounter.reverse().then((value) => animCtrlMiniArcCounter.forward());
      }
    });

    mobx.autorun((_) {
      print("got new app state");
      appModel = appRepo.appState;
      pressed = appRepo.appState.state == AppState.activated;
      _updateAnimations();
    });

    animCtrlLoading = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );
    animLoading = Tween<double>(begin: 0, end: 1).animate(animCtrlLoading)
      ..addListener(() {
        setState(() {});
      })
    ..addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        animCtrlArcStart.animateTo(0.999);
        //double newCounter = math.Random().nextDouble();
        //print(newCounter);
        animArcCounter = Tween<double>(begin: counter, end: newCounter)
          .animate(CurvedAnimation(parent: animCtrlArcCounter, curve: Curves.easeOutQuad))
          //.animate(animCtrlArcCounter)
          ..addListener(() {
            setState(() {});
          });
          // ..addStatusListener((status) {
          //   if (status == AnimationStatus.completed) {
          //     animCtrlArcStart.reverse();
          //   }
          // });
        counter = newCounter;
        animCtrlArcCounter.reset();
        animCtrlArcCounter.forward();

      animMiniArcCounter = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: animCtrlMiniArcCounter, curve: Curves.easeOutQuad))
        ..addListener(() {
          setState(() {});
        });
      animCtrlMiniArcCounter.reset();
      animCtrlMiniArcCounter.forward();
      }
    });

    animCtrlLibre = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    animLibre = Tween<double>(begin: 0, end: 1).animate(animCtrlLibre)
      ..addListener(() {
        setState(() {});
      });

    animCtrlPlus = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    animPlus = Tween<double>(begin: 0, end: 1).animate(animCtrlPlus)
      ..addListener(() {
        setState(() {});
      });

    animCtrlCover = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    animCover = Tween<double>(begin: 1, end: 0).animate(animCtrlCover)
      ..addListener(() {
        setState(() {});
      });

    animCtrlArcStart = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );
    animArcLoading = Tween<double>(begin: 0, end: 1)
      //.animate(animCtrlArcStart)
      .animate(CurvedAnimation(parent: animCtrlArcStart, curve: Curves.ease))
      ..addListener(() {
        setState(() {});
      });
      // ..addStatusListener((status) {
      //   if (status == AnimationStatus.completed) {
      //     animCtrlArcLoading.reverse();
      //   } else if (status == AnimationStatus.dismissed) {
      //     animCtrlArcLoading.forward();
      //   }
      // });

    animCtrlArcCounter = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 5000),
    );
    animArcCounter = Tween<double>(begin: 0.1, end: 0.5).animate(animCtrlArcCounter)
      ..addListener(() {
        setState(() {});
      });

    animCtrlArcAlpha = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    animArcAlpha = Tween<double>(begin: 0.0, end: 1.0).animate(animCtrlArcAlpha)
      ..addListener(() {
        setState(() {});
      });

    animCtrlMiniArcCounter = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 5000),
    );
    animCtrlMiniArcCounter.reverseDuration = Duration(milliseconds: 500);
    animMiniArcCounter = Tween<double>(begin: 0.0, end: 0.0).animate(animCtrlMiniArcCounter)
      ..addListener(() {
        setState(() {});
      });

    _updateAnimations();
  }

  Timer? timer;

  _updateAnimations() {
    print("update anim");

    animArcCounter = Tween<double>(begin: counter, end: 0.5)
      .animate(CurvedAnimation(parent: animCtrlArcCounter, curve: Curves.ease))
      //.animate(animCtrlArcCounter)
      ..addListener(() {
        setState(() {});
      });
    counter = 0.5;
    lastDayBlocked = 0.0;
    animCtrlArcCounter.reset();
    animCtrlArcCounter.forward();

    if (appModel.working) {
      animCtrlLoading.forward();
      //animCtrlArcStart.reset();
      animCtrlArcStart.repeat();
      animCtrlArcAlpha.forward();
      animCtrlMiniArcCounter.reverse();
    } else {
      animCtrlLoading.reverse();
      if (appModel.state == AppState.paused) {
        animCtrlArcAlpha.reverse();
      }
    }
    if (appModel.state == AppState.activated) {
      animCtrlLibre.forward();
    } else {
      animCtrlLibre.reverse();
    }
    if (appModel.plus) {
      animCtrlPlus.forward();
    } else {
      animCtrlPlus.reverse();
    }
    if (pressed) {
      animCtrlCover.forward();
    } else {
      animCtrlCover.reverse();
    }
  }
  
  Future<ui.Image> _load(String path) async {
    var bytes = await rootBundle.load(path);
    return decodeImageFromList(bytes.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!appModel.working) {
          setState(() {
            pressed = !pressed;
            if (pressed) {
              appRepo.unpauseApp();
            } else {
              appRepo.pauseApp();
            }
            _updateAnimations();
          });
        }
      },
      child: Column(
        children: [
          SizedBox(
            width: 210,
            height: 210,
            child: FutureBuilder<ui.Image>(
              future: loadIcon,
              builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return const CircularProgressIndicator();
                  default:
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    } else {
                      return AnimatedBuilder(
                        animation: Listenable.merge([animLoading, animLibre, animPlus, animCover, animArcLoading, animArcCounter, animArcAlpha, animMiniArcCounter]),
                        builder: (BuildContext context, Widget? child) {
                          return CustomPaint(
                            painter: PowerButtonPainter(
                              iconImage: snapshot.data!,
                              alphaLoading: animLoading.value,
                              alphaCover: animCover.value,
                              alphaLibre: animLibre.value,
                              alphaPlus: animPlus.value,
                              arcAlpha: animArcAlpha.value,
                              arcStart: animArcLoading.value,
                              arcEnd: animArcCounter.value,
                              arcCounter: [
                                animMiniArcCounter.value * math.min(1.0, statsRepo.stats.dayAllowed / math.max(statsRepo.stats.avgDayAllowed, 1.0)),
                                animMiniArcCounter.value * math.min(1.0, (statsRepo.stats.dayBlocked / math.max(statsRepo.stats.avgDayBlocked, 1.0))),
                                0
                              ],
                            ),
                          );
                        },
                      );
                    }
                }
              },
            )
          ),
          Padding(
            padding: const EdgeInsets.only(top: 64.0),
            child: (appRepo.appState.state == AppState.activated && !appRepo.appState.working) ?
              Countup(
                begin: lastDayBlocked,
                end: counter == 0.5 ? 0 : dayBlocked,
                duration: Duration(seconds: 5),
                style: Theme.of(context).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
              ) : Text("", style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white)),
          ),
          Container(
            child: (appRepo.appState.state == AppState.activated && !appRepo.appState.working) ?
              Text("blocked last 24h", style: Theme.of(context).textTheme.titleMedium) :
            (appRepo.appState.working) ?
              Text("Please wait...", style: Theme.of(context).textTheme.titleMedium) :
              Text("Tap to activate", style: Theme.of(context).textTheme.titleMedium),
          ),
          //Spacer(),
      ]),
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
    animCtrlMiniArcCounter.dispose();
    super.dispose();
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
  final arcEnd;
  final arcAlpha;
  final List<double> arcCounter;

  late Color colorCover1 = Colors.white.withOpacity(alphaCover);
  late Color colorCover2 = Colors.white.withOpacity(alphaCover);
  late Color colorRingLibre1 = Color(0xFF007AFF).withOpacity(alphaLibre);
  late Color colorRingLibre2 = Color(0xFF5856D5).withOpacity(alphaLibre);
  late Color colorRingPlus1 = Color(0xFFFF9400).withOpacity(alphaPlus);
  late Color colorRingPlus2 = Color(0xFFEF6049).withOpacity(alphaPlus);
  late Color colorArcGreen = Color(0xff33c75a).withOpacity(alphaLoading);
  late Color colorArcRed = Color(0xffff3b30).withOpacity(alphaLoading);
  late Color colorText = Colors.white;
  late Color colorLoading = Colors.white.withOpacity(alphaLoading);
  late Color colorShadow = Color(0xFF1C1C1E);

  PowerButtonPainter({
    required this.iconImage,
    required this.alphaCover, required this.alphaPlus,
    required this.alphaLibre, required this.alphaLoading,
    required this.arcStart, required this.arcEnd, required this.arcAlpha,
    required this.arcCounter
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
        ..color = Colors.white.withOpacity(math.min(arcAlpha, 0.3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWith * 0.5;

      Paint loadingArcGreenPaint = Paint()
        ..color = colorArcGreen.withOpacity(math.min(arcAlpha, 0.3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWith * 0.5;

      Paint loadingArcRedPaint = Paint()
        ..color = colorArcRed.withOpacity(math.min(arcAlpha, 0.3))
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

      Paint shadowPaint = Paint()
        ..color = colorShadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

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

      // loading arc and counter 0-1000
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 1, - ringWith * 1, size.width + ringWith * 2, size.height + ringWith * 2),
          arcStart * math.pi * 2 - math.pi / 2, arcEnd * math.pi * 2, false, loadingArcPaint);

      // counter arc 1k-10k
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 2, - ringWith * 2, size.width + ringWith * 4, size.height + ringWith * 4),
          0 - math.pi / 2, arcCounter[0] * math.pi * 2, false, loadingArcPaint);

      // counter arc 10k-100k
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 3, - ringWith * 3, size.width + ringWith * 6, size.height + ringWith * 6),
          0 - math.pi / 2, arcCounter[1] * math.pi * 2, false, loadingArcPaint);

      // counter arc 100k-1m
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 4, - ringWith * 4, size.width + ringWith * 8, size.height + ringWith * 8),
          0 - math.pi / 2, arcCounter[2] * math.pi * 2, false, loadingArcPaint);

      // draw icon
      final iconColor = (alphaPlus == 1.0) ? colorRingPlus1 :
      ((alphaLibre == 1.0) ? colorRingLibre1 :
      ((alphaCover > 0.0) ? Colors.black :
      Colors.white));

      Paint iconPaint = Paint()
        //..colorFilter = ColorFilter.mode(colorRingPlus1, BlendMode.srcIn);
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