import 'package:flutter/widgets.dart';

/// The app's one Reduce Motion check. Covers Android "remove animations"
/// (disableAnimations) and iOS Reduce Motion, which Flutter reports as a
/// separate flag; with either on, motion becomes plain crossfades.
class Motion {
  Motion._();

  static bool reduced(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
      (View.maybeOf(context)?.platformDispatcher.accessibilityFeatures.reduceMotion ?? false);
}
