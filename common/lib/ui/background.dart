import 'dart:math';

import 'package:flutter/material.dart';

class CoolBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      // painter: _MyGradientPainter(),
      painter: _MyGradientPathPainter(),
    );
  }
}

class _MyGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient1 = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.red, Colors.yellow],
    );
    final gradient2 = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Colors.green, Colors.blue],
    );
    canvas.drawRect(
      rect,
      Paint()..shader = gradient1.createShader(rect),
    );
    canvas.drawCircle(
      rect.center,
      rect.width / 2,
      Paint()..shader = gradient2.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_MyGradientPainter old) {
    return false;
  }
}

class _MyGradientPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final gradient1 = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xffff9400), Color(0xffBDBDBD)],
    );

    final gradient2 = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        Color(0xffff9400).withOpacity(0.0),
        Color(0xffFF3B30).withOpacity(0.4)
      ],
    );

    final gradient3 = LinearGradient(
      begin: Alignment.bottomRight,
      end: Alignment.topLeft,
      colors: [
        Color(0xffff9400).withOpacity(0.0),
        Color(0xFF8B5003).withOpacity(0.8)
      ],
    );

    canvas.drawRect(
      rect,
      Paint()..shader = gradient1.createShader(rect),
    );

    var path = Path();
    path.moveTo(0, 0); // Start at top left
    path.lineTo(size.width, 0); // Go to top right
    path.quadraticBezierTo(size.width, size.height / 2, 0,
        size.height * 0.7); // Go to middle right
    path.lineTo(0, size.height / 2); // Go to bottom left

    final gradient = SweepGradient(
      colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue],
      startAngle: 0.0,
      endAngle: pi * 2,
      tileMode: TileMode.repeated,
    );

    final paint = Paint()
      ..shader = gradient2.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    var path2 = Path();
    path2.moveTo(size.width, 0);
    path2.lineTo(0, 0);
    path2.quadraticBezierTo(0, size.height / 2, size.width,
        size.height * 0.7); // Go to middle right
    path2.lineTo(size.width, size.height / 2); // Go to bottom left

    final paint2 = Paint()
      ..shader = gradient3.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(_MyGradientPathPainter oldDelegate) => false;
}
