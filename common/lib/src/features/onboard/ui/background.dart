import 'dart:math';

import 'package:common/src/core/core.dart';
import 'package:flutter/material.dart';

class ColorfulBackground extends StatelessWidget {
  const ColorfulBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final painter = Core.act.isFamily ? _FamilyPainter() : _SixPainter();
    return CustomPaint(
      size: Size.infinite,
      painter: painter,
    );
  }
}

class _FamilyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final gradient1 = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xff4ae5f6).withOpacity(0.8),
        Color(0xff3b8dff),
        Color(0xff3b8dff),
      ],
    );

    final gradient2 = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        const Color(0xffe450cd).withOpacity(0.0),
        const Color(0xffe450cd),
      ],
    );

    canvas.drawRect(
      rect,
      Paint()..shader = gradient1.createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()..shader = gradient2.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_FamilyPainter oldDelegate) => false;
}

class _SixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final gradient1 = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xffEE5F48),
        Color(0xffFF9400).withOpacity(0.8),
      ],
    );

    final gradient2 = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xffFF9400).withOpacity(0.0),
        const Color(0xffFF9400),
      ],
    );

    canvas.drawRect(
      rect,
      Paint()..shader = gradient1.createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()..shader = gradient2.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SixPainter oldDelegate) => false;
}
