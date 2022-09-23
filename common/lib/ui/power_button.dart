import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
 import 'package:mobx/mobx.dart' as mobx;
import 'dart:ui' as ui;
import 'dart:math' as math;

import '../model/AppModel.dart';
import '../repo/Repos.dart';

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

  @override
  void initState() {
    super.initState();
    loadIcon = _load("assets/images/ic_power.png");

    mobx.autorun((_) {
      total = Repos.instance.stats.stats.totalBlocked;
      newCounter = math.min(1.0, (total % 1000) / 1000.0);

      if (!animCtrlArcCounter.isAnimating) {
        animArcCounter = Tween<double>(begin: counter, end: newCounter)
          .animate(CurvedAnimation(parent: animCtrlArcCounter, curve: Curves.easeOutQuad))
          ..addListener(() {
            setState(() {});
          });
        counter = newCounter;
        animCtrlArcCounter.reset();
        animCtrlArcCounter.forward();
        animCtrlMiniArcCounter.reverse().then((value) => animCtrlMiniArcCounter.forward());
      }
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
      duration: Duration(milliseconds: 1000),
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

  _upd() {
    print("timer");
    setState(() {
      if (appModel.state == AppState.paused) {
        appModel = AppModel(state: AppState.activated, working: false, plus: false);
      } else if (!appModel.plus) {
        appModel = AppModel(state: AppState.activated, working: false, plus: true);
        pressed = true;
      } else {
        appModel = AppModel(state: AppState.paused, working: false, plus: false);
      }
      _updateAnimations();
    });
    timer?.cancel();
    timer = null;
  }

  _updateAnimations() {
    print("update anim");

    animArcCounter = Tween<double>(begin: counter, end: 0.5)
      .animate(CurvedAnimation(parent: animCtrlArcCounter, curve: Curves.ease))
      //.animate(animCtrlArcCounter)
      ..addListener(() {
        setState(() {});
      });
    counter = 0.5;
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
            appModel = AppModel(state: appModel.state, working: true, plus: appModel.plus);
            timer = Timer.periodic(const Duration(seconds: 3), (Timer t) => _upd());
            _updateAnimations();
          });
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
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
                                animMiniArcCounter.value * (((total % 10000) ~/ 1000) * 0.1),
                                animMiniArcCounter.value * (((total % 100000) ~/ 10000) * 0.1),
                                animMiniArcCounter.value * (((total % 1000000) ~/ 100000) * 0.1),
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
          // SizedBox(
          //   width: 500,
          //   height: 500,
          //   child: IgnorePointer(
          //     ignoring: true,
          //     child: PowerButtonRadial(stats: UiStats.empty(totalBlocked: 900))
          //   )
          // )
      ]),
    );
  }

  @override
  void dispose() {
    animCtrlLoading.dispose();
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
        ..color = Colors.white.withOpacity(arcAlpha)
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
          stops: [0.0, 0.88, 0.98],
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
          Rect.fromLTWH(- ringWith * 1, - ringWith * 3, size.width + ringWith * 2, size.height + ringWith * 6),
          arcStart * math.pi * 2 - math.pi / 2, arcEnd * math.pi * 2, false, loadingArcPaint);

      // counter arc 1k-10k
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 2, - ringWith * 4, size.width + ringWith * 4, size.height + ringWith * 8),
          0 - math.pi / 2, arcCounter[0] * math.pi * 2, false, loadingArcPaint);

      // counter arc 10k-100k
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 3, - ringWith * 5, size.width + ringWith * 6, size.height + ringWith * 10),
          0 - math.pi / 2, arcCounter[1] * math.pi * 2, false, loadingArcPaint);

      // counter arc 100k-1m
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 4, - ringWith * 6, size.width + ringWith * 8, size.height + ringWith * 12),
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