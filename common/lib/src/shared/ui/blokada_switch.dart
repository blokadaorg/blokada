import 'package:common/src/shared/ui/haptics.dart';
import 'package:flutter/cupertino.dart';

/// The app's on/off switch: a [CupertinoSwitch] that gives a selection click
/// when the user flips it, or no haptic when [haptic] is off and the caller
/// plays its own.
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
    return CupertinoSwitch(
      value: value,
      activeTrackColor: activeColor,
      onChanged: onChanged == null
          ? null
          : (v) {
              if (haptic) Haptics.selection();
              onChanged(v);
            },
    );
  }
}
