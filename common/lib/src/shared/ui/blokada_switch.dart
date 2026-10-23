import 'package:common/src/shared/ui/haptics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The app's on/off switch: the platform's own switch (a [CupertinoSwitch]
/// on iOS, a Material [Switch] elsewhere) that gives a selection click when
/// the user flips it, or no haptic when [haptic] is off and the caller plays
/// its own.
///
/// The platform comes from the theme rather than `dart:io`, so widget tests
/// and goldens can render either one.
class BlokadaSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final bool haptic;

  const BlokadaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.haptic = true,
  });

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final ValueChanged<bool>? onFlip = onChanged == null
        ? null
        : (v) {
            if (haptic) Haptics.selection();
            onChanged(v);
          };

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoSwitch(
        value: value,
        activeTrackColor: activeColor,
        onChanged: onFlip,
      );
    }

    // A Material switch needs a Material ancestor, which sheets built from
    // Cupertino widgets don't have; a transparent one draws nothing.
    return Material(
      type: MaterialType.transparency,
      child: Switch(
        value: value,
        activeTrackColor: activeColor,
        // Keep the footprint of the iOS switch, so the rows built around it
        // (like the fixed-height Plus card) keep their size.
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: onFlip,
      ),
    );
  }
}
