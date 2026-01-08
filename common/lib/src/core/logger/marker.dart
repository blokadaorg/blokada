part of '../core.dart';

// Marker helps to track execution chains and categorize logs.
typedef Marker = int;

class Markers {
  static const root = 0; // Dont use
  static const start = 1; // Start sequence
  static const platform = 2; // Triggered by platform code (ios/android)
  static const userTap = 3; // User action (tap, swipe, etc.)
  static const testing = 4; // Only used in test cases
  static const auth = 5;
  static const stats = 6;
  static const support = 7;
  static const timer = 8; // Timed triggers
  static const device = 9;
  static const filter = 10;
  static const ui = 11; // Triggered by UI rendering code
  static const perm = 12;
  static const persistence = 13;
  static const valueChange = 14;

  static String toName(Marker marker) {
    switch (marker) {
      case root:
        return "root";
      case start:
        return "start";
      case platform:
        return "platform";
      case userTap:
        return "userTap";
      case testing:
        return "testing";
      case auth:
        return "auth";
      case stats:
        return "stats";
      case support:
        return "support";
      case timer:
        return "timer";
      case device:
        return "device";
      case filter:
        return "filter";
      case ui:
        return "ui";
      case perm:
        return "onboard";
      case persistence:
        return "persistence";
      case valueChange:
        return "valueChange";
      default:
        return "unknown";
    }
  }
}
