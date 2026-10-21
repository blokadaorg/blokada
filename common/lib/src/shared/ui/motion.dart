import 'package:flutter/widgets.dart';

/// The app's one Reduce Motion check. Covers iOS Reduce Motion and Android
/// "remove animations"; with it on, motion becomes plain crossfades.
class Motion {
  Motion._();

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
