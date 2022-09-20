import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

import '../model/AppModel.dart';

class PowerButton extends StatelessWidget {

  final AppModel appModel;

  PowerButton({
    Key? key, required this.appModel
  }) : super(key: key);

  Future<ui.Image> _load(String path) async {
    var bytes = await rootBundle.load(path);
    return decodeImageFromList(bytes.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: FutureBuilder<ui.Image>(
        future: _load("assets/images/ic_power.png"),
        builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return const CircularProgressIndicator();
            default:
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else {
                return CustomPaint(
                  painter: PowerButtonPainter(
                      iconImage: snapshot.data!,
                      appModel: appModel
                  ),
                );
              }
            }
        },
      )
    );
  }

}

class PowerButtonPainter extends CustomPainter {

  final AppModel appModel;
  final ui.Image iconImage;

  final edge = 9.0;
  final ringWith = 6.0;
  final iconWidth = 160.0;
    final blurRadius = 5.0;

    final colorRingLibre1 = Color(0xFF007AFF);
    final colorRingLibre2 = Color(0xFF5856D5);
    final colorRingPlus1 = Color(0xFFFF9400);
    final colorRingPlus2 = Color(0xFFEF6049);
    final colorText = Colors.white;
    final colorShadow = Color(0xFF1C1C1E);

    PowerButtonPainter({
      required this.appModel, required this.iconImage
    });

    @override
    void paint(Canvas canvas, Size size) {
      Rect rect = Offset.zero & size;

      Paint offPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.white30,
          ],
        ).createShader(rect);

      Paint inactiveRingPaint = Paint()
        ..color = colorShadow
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWith;

      Paint loadingRingPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWith;

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
            0.0, 0.88, 0.95
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

      // ring loading
      // loadingRingPaint.alpha = alphaLoading
      // canvas.drawCircle(contentWidth / 2f, contentHeight / 2f, contentWidth / 2f - ringWidth * 2.1f, loadingRingPaint)

      // Filled background when active
      //canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - edge, innerShadowPaint);

      // ring blue
      //libreRingPaint.alpha = alphaBlue
      //canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - ringWith, libreRingPaint);

      // ring orange
      // plusRingPaint.alpha = alphaOrange
      //canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - ringWith, plusRingPaint);

      // shadow and the off state cover
      // shadowPaint.alpha = alphaCover
      // offButtonPaint.alpha = alphaCover
      //canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - edge * 0.5, shadowPaint);
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - edge * 1.7, offPaint);

      // draw icon
      Paint iconPaint = Paint()
        //..colorFilter = ColorFilter.mode(colorRingPlus1, BlendMode.srcIn);
        ..colorFilter = ColorFilter.mode(Colors.black, BlendMode.srcIn);

      canvas.drawImage(iconImage,
          Offset(size.width / 2 - iconImage.width / 2, size.height / 2 - iconImage.height / 2),
          iconPaint);

    }

    @override
    bool shouldRepaint(CustomPainter oldDelegate) {
      return true;
    }

}