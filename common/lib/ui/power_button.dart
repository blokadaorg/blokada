import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

import '../model/AppModel.dart';

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
  late AnimationController animCtrlArcLoading;

  late Animation<double> animLoading;
  late Animation<double> animLibre;
  late Animation<double> animPlus;
  late Animation<double> animCover;
  late Animation<double> animArcLoading;

  bool pressed = false;

  @override
  void initState() {
    super.initState();
    loadIcon = _load("assets/images/ic_power.png");

    animCtrlLoading = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    animLoading = Tween<double>(begin: 0, end: 1).animate(animCtrlLoading)
      ..addListener(() {
        setState(() {});
      })
    ..addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        animCtrlArcLoading.stop();
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

    animCtrlArcLoading = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );
    animArcLoading = Tween<double>(begin: 0, end: 1).animate(animCtrlArcLoading)
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
    if (appModel.working) {
      animCtrlLoading.forward();
      animCtrlArcLoading.reset();
      animCtrlArcLoading.repeat();
    } else {
      animCtrlLoading.reverse();
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
      child: SizedBox(
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
                    //animCtrlLoading.forward();
                    return AnimatedBuilder(
                      animation: Listenable.merge([animLoading, animLibre, animPlus, animCover, animArcLoading]),
                      builder: (BuildContext context, Widget? child) {
                        return CustomPaint(
                          painter: PowerButtonPainter(
                            iconImage: snapshot.data!,
                            alphaLoading: animLoading.value,
                            alphaCover: animCover.value,
                            alphaLibre: animLibre.value,
                            alphaPlus: animPlus.value,
                            arcLoading: animArcLoading.value
                          ),
                        );
                      },
                    );
                  }
              }
            },
          )
      ),
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
  final arcLoading;

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
    required this.arcLoading
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
        ..color = colorLoading
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
          stops: [
            0.0, 0.88, 0.98
          ],
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

      // loading arc
      canvas.drawArc(
          Rect.fromLTWH(- ringWith * 1, - ringWith * 3, size.width + ringWith * 2, size.height + ringWith * 6),
          arcLoading * math.pi * 2, math.pi / 1, false, loadingArcPaint);

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