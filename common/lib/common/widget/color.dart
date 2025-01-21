import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

Color genColor(String id, {bool isDarkMode = false}) {
  final bytes = utf8.encode(id);
  final hash = sha256.convert(bytes);
  final hashBytes = hash.bytes;

  // Suppose we combine a few bytes for the hue:
  int hueValue = (hashBytes[0] << 24) |
      (hashBytes[1] << 16) |
      (hashBytes[2] << 8) |
      hashBytes[3];
  double hue = (hueValue % 360).toDouble();

  // Maybe saturate and lighten them a bit
  double saturation = 0.7;
  double lightness = 0.5;

  // Convert HSL → RGB
  final rgb = _hslToRgb(hue, saturation, lightness);
  return Color.fromRGBO(rgb.r, rgb.g, rgb.b, 1.0);
}

class RGB {
  final int r, g, b;
  RGB(this.r, this.g, this.b);
}

RGB _hslToRgb(double hue, double saturation, double lightness) {
  // 1. Normalize hue to be within [0, 360)
  hue = hue % 360;

  double c = (1.0 - (2.0 * lightness - 1.0).abs()) * saturation;
  double x = c * (1.0 - (((hue / 60.0) % 2.0) - 1.0).abs());
  double m = lightness - c / 2.0;

  double rPrime, gPrime, bPrime;

  if (hue < 60) {
    rPrime = c;
    gPrime = x;
    bPrime = 0;
  } else if (hue < 120) {
    rPrime = x;
    gPrime = c;
    bPrime = 0;
  } else if (hue < 180) {
    rPrime = 0;
    gPrime = c;
    bPrime = x;
  } else if (hue < 240) {
    rPrime = 0;
    gPrime = x;
    bPrime = c;
  } else if (hue < 300) {
    rPrime = x;
    gPrime = 0;
    bPrime = c;
  } else {
    rPrime = c;
    gPrime = 0;
    bPrime = x;
  }

  // Convert to 0–255 range
  int r = ((rPrime + m) * 255).round();
  int g = ((gPrime + m) * 255).round();
  int b = ((bPrime + m) * 255).round();

  return RGB(r, g, b);
}

Color _genColorRgb(String id) {
  final bytes = utf8.encode(id);
  final hash = sha256.convert(bytes);
  final hashBytes = hash.bytes;

  // Combine pairs of bytes for R, G, B
  final r = ((hashBytes[0] << 8) + hashBytes[1]) % 256;
  final g = ((hashBytes[2] << 8) + hashBytes[3]) % 256;
  final b = ((hashBytes[4] << 8) + hashBytes[5]) % 256;

  return Color.fromRGBO(r, g, b, 1);
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
