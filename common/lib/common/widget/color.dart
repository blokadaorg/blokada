import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

Color genColor(String id) {
  final bytes = utf8.encode(id);
  final hash = sha256.convert(bytes);
  final hashBytes = hash.bytes;

  double red = hashBytes[0] / 255.0;
  double green = hashBytes[1] / 255.0;
  double blue = hashBytes[2] / 255.0;

  return Color.fromRGBO(
      (red * 255).round(), (green * 255).round(), (blue * 255).round(), 1);
}

extension ColorExtension on Color {
  /// Convert the color to a darken color based on the [percent]
  Color darken([int percent = 40]) {
    assert(
        percent >= 0 && percent <= 100, 'Percent should be between 0 and 100');
    final hsl = HSLColor.fromColor(this);
    final hslDarkened =
        hsl.withLightness((hsl.lightness - percent / 100.0).clamp(0.0, 1.0));
    return hslDarkened.toColor();
  }

  Color lighten([int percent = 40]) {
    assert(
        percent >= 0 && percent <= 100, 'Percent should be between 0 and 100');
    final hsl = HSLColor.fromColor(this);
    final hslLightened =
        hsl.withLightness((hsl.lightness + percent / 100.0).clamp(0.0, 1.0));

    return hslLightened.toColor();
  }
}
