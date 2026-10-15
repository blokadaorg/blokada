import 'package:flutter/services.dart';

/// The app's haptic vocabulary, so the strength of each kind is tuned in one
/// place. Flutter's [HapticFeedback] uses the system haptics on both platforms
/// and follows the OS setting.
class Haptics {
  Haptics._();

  /// A primary action, like the power button.
  static Future<void> tap() => HapticFeedback.mediumImpact();

  /// Something small happened: pause, turn off, copy, saved, pull to refresh.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// A value changed: switches and segmented controls.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// A confirmed outcome, like protection turning on. Flutter has no success
  /// type, so it's two light impacts close together.
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }
}
